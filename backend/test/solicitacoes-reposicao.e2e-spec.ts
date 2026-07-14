import { INestApplication } from '@nestjs/common';
import { AulaStatus, PresencaStatus, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import {
  createAcademiaFixture,
  createAlunoFixture,
  createMatriculaFixture,
  createModalidadeFixture,
  createPlanoFixture,
  createProfessorFixture,
} from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

const SENHA = 'SenhaForte123';

describe('SolicitacoesReposicao (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string) {
    const email = `${role.toLowerCase()}-reposicao-${Date.now()}-${Math.random()}@example.com`;
    const user = await prisma.user.create({
      data: {
        nome: `Usuário ${role}`,
        email,
        senhaHash: await bcrypt.hash(SENHA, 10),
        role,
        academiaId,
      },
    });
    const res = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email, password: SENHA })
      .expect(200);
    return { token: res.body.accessToken as string, userId: user.id };
  }

  async function cenarioBase(nomeAcademia: string) {
    const academia = await createAcademiaFixture(prisma, { nome: nomeAcademia });
    const { token, userId } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    const modalidade = await createModalidadeFixture(prisma, academia.id);
    const professor = await createProfessorFixture(prisma, academia.id);
    const plano = await createPlanoFixture(prisma, academia.id);

    const turma = await request(app.getHttpServer())
      .post('/api/agenda/turmas')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Turma Reposição', modalidadeId: modalidade.id, professorId: professor.id })
      .expect(201);

    const aluno = await createAlunoFixture(prisma, academia.id);
    await createMatriculaFixture(prisma, academia.id, aluno.id, plano.id, userId);

    const turmaAluno = await request(app.getHttpServer())
      .post(`/api/agenda/turmas/${turma.body.id}/alunos`)
      .set('Authorization', `Bearer ${token}`)
      .send({ alunoId: aluno.id })
      .expect(201);

    return { academia, token, userId, professor, turma: turma.body, aluno, turmaAluno: turmaAluno.body };
  }

  async function criarAula(
    academiaId: string,
    turmaId: string,
    professorId: string,
    userId: string,
    data: Date,
    options: { status?: AulaStatus; capacidadeMaxima?: number | null } = {},
  ) {
    return prisma.aula.create({
      data: {
        academiaId,
        turmaId,
        recorrenciaId: null,
        data,
        horaInicio: '07:00',
        duracaoMinutos: 60,
        professorId,
        capacidadeMaxima: options.capacidadeMaxima ?? null,
        status: options.status ?? AulaStatus.AGENDADA,
        createdByUserId: userId,
      },
    });
  }

  async function criarAulaAluno(
    academiaId: string,
    aulaId: string,
    alunoId: string,
    turmaAlunoId: string,
    presenca: PresencaStatus | null = null,
  ) {
    return prisma.aulaAluno.create({
      data: { academiaId, aulaId, alunoId, turmaAlunoId, tipo: 'MATRICULADO', presenca },
    });
  }

  function diasAtras(dias: number): Date {
    const data = new Date();
    data.setUTCDate(data.getUTCDate() - dias);
    return new Date(Date.UTC(data.getUTCFullYear(), data.getUTCMonth(), data.getUTCDate()));
  }

  function diasAFrente(dias: number): Date {
    const data = new Date();
    data.setUTCDate(data.getUTCDate() + dias);
    return new Date(Date.UTC(data.getUTCFullYear(), data.getUTCMonth(), data.getUTCDate()));
  }

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('sem token -> 401', async () => {
    await request(app.getHttpServer()).get('/api/agenda/solicitacoes-reposicao').expect(401);
  });

  it('PROFESSOR não tem acesso (403)', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Prof Sem Acesso Reposicao E2E' });
    const { token } = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    await request(app.getHttpServer())
      .get('/api/agenda/solicitacoes-reposicao')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  describe('Criar solicitação', () => {
    it('origem com falta (AUSENTE) -> 201, sem aulaDestinoId', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Criar Falta E2E',
      );
      const aula = await criarAula(academia.id, turma.id, professor.id, userId, diasAtras(2));
      const aulaAluno = await criarAulaAluno(academia.id, aula.id, aluno.id, turmaAluno.id, 'AUSENTE');

      const criada = await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: aulaAluno.id, observacoes: 'Aluno viajou' })
        .expect(201);

      expect(criada.body.status).toBe('PENDENTE');
      expect(criada.body.aulaDestinoId).toBeNull();
      expect(criada.body.alunoId).toBe(aluno.id);
      expect(criada.body.aulaOrigemTurmaNome).toBe(turma.nome);

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'SOLICITACAO_REPOSICAO_CRIADA', academiaId: academia.id },
      });
      expect(auditEntry).not.toBeNull();
      expect(auditEntry?.ipAddress).toBeTruthy();
    });

    it('origem com aula cancelada -> 201', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Criar Cancelada E2E',
      );
      const aula = await criarAula(academia.id, turma.id, professor.id, userId, diasAtras(1), {
        status: AulaStatus.CANCELADA,
      });
      const aulaAluno = await criarAulaAluno(academia.id, aula.id, aluno.id, turmaAluno.id, null);

      await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: aulaAluno.id })
        .expect(201);
    });

    it('origem com presença PRESENTE -> 400', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Origem Presente E2E',
      );
      const aula = await criarAula(academia.id, turma.id, professor.id, userId, diasAtras(1));
      const aulaAluno = await criarAulaAluno(academia.id, aula.id, aluno.id, turmaAluno.id, 'PRESENTE');

      await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: aulaAluno.id })
        .expect(400);
    });

    it('origem sem presença marcada e não cancelada -> 400', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Origem Sem Presenca E2E',
      );
      const aula = await criarAula(academia.id, turma.id, professor.id, userId, diasAtras(1));
      const aulaAluno = await criarAulaAluno(academia.id, aula.id, aluno.id, turmaAluno.id, null);

      await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: aulaAluno.id })
        .expect(400);
    });

    it('origem de aula futura -> 400', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Origem Futura E2E',
      );
      const aula = await criarAula(academia.id, turma.id, professor.id, userId, diasAFrente(3), {
        status: AulaStatus.CANCELADA,
      });
      const aulaAluno = await criarAulaAluno(academia.id, aula.id, aluno.id, turmaAluno.id, null);

      await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: aulaAluno.id })
        .expect(400);
    });

    it('aulaAlunoOrigemId inexistente -> 404', async () => {
      const { token } = await cenarioBase('Academia Origem Inexistente E2E');

      await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: '00000000-0000-4000-8000-000000000099' })
        .expect(404);
    });

    it('já existe solicitação ativa pra mesma origem -> 409', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Origem Duplicada E2E',
      );
      const aula = await criarAula(academia.id, turma.id, professor.id, userId, diasAtras(1));
      const aulaAluno = await criarAulaAluno(academia.id, aula.id, aluno.id, turmaAluno.id, 'AUSENTE');

      await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: aulaAluno.id })
        .expect(201);

      await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: aulaAluno.id })
        .expect(409);
    });
  });

  describe('Aprovar', () => {
    it('aprova, escolhendo destino agora — cria AulaAluno(tipo=REPOSICAO)', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Aprovar E2E',
      );
      const origemAula = await criarAula(academia.id, turma.id, professor.id, userId, diasAtras(1));
      const origem = await criarAulaAluno(academia.id, origemAula.id, aluno.id, turmaAluno.id, 'AUSENTE');
      const destinoAula = await criarAula(academia.id, turma.id, professor.id, userId, diasAFrente(5));

      const solicitacao = await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: origem.id })
        .expect(201);

      const aprovada = await request(app.getHttpServer())
        .patch(`/api/agenda/solicitacoes-reposicao/${solicitacao.body.id}/aprovar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaDestinoId: destinoAula.id })
        .expect(200);

      expect(aprovada.body.status).toBe('APROVADA');
      expect(aprovada.body.aulaDestinoId).toBe(destinoAula.id);

      const aulaAlunoReposicao = await prisma.aulaAluno.findFirst({
        where: { aulaId: destinoAula.id, alunoId: aluno.id },
      });
      expect(aulaAlunoReposicao).not.toBeNull();
      expect(aulaAlunoReposicao?.tipo).toBe('REPOSICAO');
      expect(aulaAlunoReposicao?.reposicaoDeAulaAlunoId).toBe(origem.id);

      const auditAprovada = await prisma.auditLog.findFirst({
        where: { action: 'SOLICITACAO_REPOSICAO_APROVADA', academiaId: academia.id },
      });
      expect(auditAprovada).not.toBeNull();
      const auditReposicao = await prisma.auditLog.findFirst({
        where: { action: 'AULA_ALUNO_REPOSICAO_CRIADA', academiaId: academia.id },
      });
      expect(auditReposicao).not.toBeNull();
    });

    it('destino sem vaga -> 409, sem criar AulaAluno nem alterar a solicitação', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Aprovar Sem Vaga E2E',
      );
      const origemAula = await criarAula(academia.id, turma.id, professor.id, userId, diasAtras(1));
      const origem = await criarAulaAluno(academia.id, origemAula.id, aluno.id, turmaAluno.id, 'AUSENTE');

      const destinoAula = await criarAula(academia.id, turma.id, professor.id, userId, diasAFrente(5), {
        capacidadeMaxima: 1,
      });
      const outroAluno = await createAlunoFixture(prisma, academia.id);
      await prisma.aulaAluno.create({
        data: { academiaId: academia.id, aulaId: destinoAula.id, alunoId: outroAluno.id, tipo: 'MATRICULADO' },
      });

      const solicitacao = await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: origem.id })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/agenda/solicitacoes-reposicao/${solicitacao.body.id}/aprovar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaDestinoId: destinoAula.id })
        .expect(409);

      const aindaPendente = await prisma.solicitacaoReposicao.findUniqueOrThrow({
        where: { id: solicitacao.body.id },
      });
      expect(aindaPendente.status).toBe('PENDENTE');
      expect(aindaPendente.aulaDestinoId).toBeNull();
    });

    it('destino cancelado -> 400', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Aprovar Destino Cancelado E2E',
      );
      const origemAula = await criarAula(academia.id, turma.id, professor.id, userId, diasAtras(1));
      const origem = await criarAulaAluno(academia.id, origemAula.id, aluno.id, turmaAluno.id, 'AUSENTE');
      const destinoAula = await criarAula(academia.id, turma.id, professor.id, userId, diasAFrente(5), {
        status: AulaStatus.CANCELADA,
      });

      const solicitacao = await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: origem.id })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/agenda/solicitacoes-reposicao/${solicitacao.body.id}/aprovar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaDestinoId: destinoAula.id })
        .expect(400);
    });

    it('destino no passado -> 400', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Aprovar Destino Passado E2E',
      );
      const origemAula = await criarAula(academia.id, turma.id, professor.id, userId, diasAtras(2));
      const origem = await criarAulaAluno(academia.id, origemAula.id, aluno.id, turmaAluno.id, 'AUSENTE');
      const destinoAula = await criarAula(academia.id, turma.id, professor.id, userId, diasAtras(1));

      const solicitacao = await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: origem.id })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/agenda/solicitacoes-reposicao/${solicitacao.body.id}/aprovar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaDestinoId: destinoAula.id })
        .expect(400);
    });

    it('aluno já vinculado à aula de destino -> 400', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Aprovar Ja Vinculado E2E',
      );
      const origemAula = await criarAula(academia.id, turma.id, professor.id, userId, diasAtras(1));
      const origem = await criarAulaAluno(academia.id, origemAula.id, aluno.id, turmaAluno.id, 'AUSENTE');
      const destinoAula = await criarAula(academia.id, turma.id, professor.id, userId, diasAFrente(5));
      await criarAulaAluno(academia.id, destinoAula.id, aluno.id, turmaAluno.id, null);

      const solicitacao = await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: origem.id })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/agenda/solicitacoes-reposicao/${solicitacao.body.id}/aprovar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaDestinoId: destinoAula.id })
        .expect(400);
    });

    it('solicitação já decidida -> 400', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Aprovar Ja Decidida E2E',
      );
      const origemAula = await criarAula(academia.id, turma.id, professor.id, userId, diasAtras(1));
      const origem = await criarAulaAluno(academia.id, origemAula.id, aluno.id, turmaAluno.id, 'AUSENTE');
      const destinoAula = await criarAula(academia.id, turma.id, professor.id, userId, diasAFrente(5));

      const solicitacao = await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: origem.id })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/agenda/solicitacoes-reposicao/${solicitacao.body.id}/rejeitar`)
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(200);

      await request(app.getHttpServer())
        .patch(`/api/agenda/solicitacoes-reposicao/${solicitacao.body.id}/aprovar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaDestinoId: destinoAula.id })
        .expect(400);
    });
  });

  describe('Rejeitar', () => {
    it('rejeita com motivo, e permite nova solicitação pra mesma origem depois', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Rejeitar E2E',
      );
      const origemAula = await criarAula(academia.id, turma.id, professor.id, userId, diasAtras(1));
      const origem = await criarAulaAluno(academia.id, origemAula.id, aluno.id, turmaAluno.id, 'AUSENTE');

      const solicitacao = await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: origem.id })
        .expect(201);

      const rejeitada = await request(app.getHttpServer())
        .patch(`/api/agenda/solicitacoes-reposicao/${solicitacao.body.id}/rejeitar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ motivoRejeicao: 'Sem vaga em nenhuma aula compatível' })
        .expect(200);
      expect(rejeitada.body.status).toBe('REJEITADA');
      expect(rejeitada.body.motivoRejeicao).toBe('Sem vaga em nenhuma aula compatível');

      const auditRejeitada = await prisma.auditLog.findFirst({
        where: { action: 'SOLICITACAO_REPOSICAO_REJEITADA', academiaId: academia.id },
      });
      expect(auditRejeitada).not.toBeNull();

      // Decisão 6 (docs/21): rejeitada não bloqueia uma nova solicitação
      await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: origem.id })
        .expect(201);
    });
  });

  describe('Listagem', () => {
    it('filtra por status e ordena por criação (mais recente primeiro)', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Listagem E2E',
      );
      const aula1 = await criarAula(academia.id, turma.id, professor.id, userId, diasAtras(3));
      const origem1 = await criarAulaAluno(academia.id, aula1.id, aluno.id, turmaAluno.id, 'AUSENTE');
      const aula2 = await criarAula(academia.id, turma.id, professor.id, userId, diasAtras(2));
      const origem2 = await criarAulaAluno(academia.id, aula2.id, aluno.id, turmaAluno.id, 'AUSENTE');

      const primeira = await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: origem1.id })
        .expect(201);
      const segunda = await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .send({ aulaAlunoOrigemId: origem2.id })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/agenda/solicitacoes-reposicao/${primeira.body.id}/rejeitar`)
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(200);

      const pendentes = await request(app.getHttpServer())
        .get('/api/agenda/solicitacoes-reposicao?status=PENDENTE')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(pendentes.body.total).toBe(1);
      expect(pendentes.body.items[0].id).toBe(segunda.body.id);

      const todas = await request(app.getHttpServer())
        .get('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(todas.body.total).toBe(2);
      expect(todas.body.items[0].id).toBe(segunda.body.id);
      expect(todas.body.items[1].id).toBe(primeira.body.id);
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê, aprova nem rejeita solicitação da academia B', async () => {
      const cenarioA = await cenarioBase('Academia Isolamento Reposicao A E2E');
      const cenarioB = await cenarioBase('Academia Isolamento Reposicao B E2E');
      const aulaB = await criarAula(
        cenarioB.academia.id,
        cenarioB.turma.id,
        cenarioB.professor.id,
        cenarioB.userId,
        diasAtras(1),
      );
      const origemB = await criarAulaAluno(
        cenarioB.academia.id,
        aulaB.id,
        cenarioB.aluno.id,
        cenarioB.turmaAluno.id,
        'AUSENTE',
      );
      const solicitacaoB = await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${cenarioB.token}`)
        .send({ aulaAlunoOrigemId: origemB.id })
        .expect(201);

      await request(app.getHttpServer())
        .get(`/api/agenda/solicitacoes-reposicao?status=PENDENTE`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(200)
        .then((res) => {
          expect(res.body.items.some((item: { id: string }) => item.id === solicitacaoB.body.id)).toBe(false);
        });

      await request(app.getHttpServer())
        .patch(`/api/agenda/solicitacoes-reposicao/${solicitacaoB.body.id}/rejeitar`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({})
        .expect(404);
    });
  });
});
