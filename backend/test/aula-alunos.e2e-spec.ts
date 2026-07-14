import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
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

describe('AulaAlunos — Frequencia (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string) {
    const email = `${role.toLowerCase()}-frequencia-${Date.now()}-${Math.random()}@example.com`;
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

  /// Academia + token + turma + 1 aluno com TurmaAluno ativo — pronto pra
  /// criar Aulas (direto via Prisma, sem passar pelo gerador do MS6) com
  /// datas passadas/futuras e status AGENDADA/CANCELADA.
  async function cenarioBase(nomeAcademia: string) {
    const academia = await createAcademiaFixture(prisma, { nome: nomeAcademia });
    const { token, userId } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    const modalidade = await createModalidadeFixture(prisma, academia.id);
    const professor = await createProfessorFixture(prisma, academia.id);
    const plano = await createPlanoFixture(prisma, academia.id);

    const turma = await request(app.getHttpServer())
      .post('/api/agenda/turmas')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Turma Frequência', modalidadeId: modalidade.id, professorId: professor.id })
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

  async function criarAulaComAluno(
    academiaId: string,
    turmaId: string,
    professorId: string,
    userId: string,
    alunoId: string,
    turmaAlunoId: string,
    data: Date,
    status: 'AGENDADA' | 'CANCELADA' = 'AGENDADA',
  ) {
    const aula = await prisma.aula.create({
      data: {
        academiaId,
        turmaId,
        recorrenciaId: null,
        data,
        horaInicio: '07:00',
        duracaoMinutos: 60,
        professorId,
        capacidadeMaxima: null,
        status,
        createdByUserId: userId,
      },
    });
    const aulaAluno = await prisma.aulaAluno.create({
      data: {
        academiaId,
        aulaId: aula.id,
        alunoId,
        turmaAlunoId,
        tipo: 'MATRICULADO',
      },
    });
    return { aula, aulaAluno };
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
    const { turma } = await cenarioBase('Academia Frequencia Sem Token E2E');
    await request(app.getHttpServer()).get(`/api/agenda/aulas/${turma.id}/alunos`).expect(401);
  });

  it('PROFESSOR não tem acesso (403)', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Frequencia Prof Sem Acesso E2E' });
    const { token } = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    await request(app.getHttpServer())
      .get('/api/agenda/alunos/00000000-0000-4000-8000-000000000099/frequencia')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  describe('Registrar presença', () => {
    it('registra presença numa aula realizada e permite alterar depois', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Presenca Realizada E2E',
      );
      const { aula, aulaAluno } = await criarAulaComAluno(
        academia.id,
        turma.id,
        professor.id,
        userId,
        aluno.id,
        turmaAluno.id,
        diasAtras(1),
      );

      const marcada = await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${aula.id}/alunos/${aulaAluno.id}/presenca`)
        .set('Authorization', `Bearer ${token}`)
        .send({ presenca: 'PRESENTE' })
        .expect(200);
      expect(marcada.body.presenca).toBe('PRESENTE');

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'AULA_ALUNO_PRESENCA_MARCADA', academiaId: academia.id },
      });
      expect(auditEntry?.metadata).toMatchObject({
        aulaAlunoId: aulaAluno.id,
        presencaAnterior: null,
        presencaNova: 'PRESENTE',
      });

      // Altera a presença já marcada (mesma operação, docs/18 "Frequência — invariante 4")
      const alterada = await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${aula.id}/alunos/${aulaAluno.id}/presenca`)
        .set('Authorization', `Bearer ${token}`)
        .send({ presenca: 'AUSENTE' })
        .expect(200);
      expect(alterada.body.presenca).toBe('AUSENTE');

      const auditAlteracao = await prisma.auditLog.findFirst({
        where: { action: 'AULA_ALUNO_PRESENCA_MARCADA', academiaId: academia.id },
        orderBy: { createdAt: 'desc' },
      });
      expect(auditAlteracao?.metadata).toMatchObject({ presencaAnterior: 'PRESENTE', presencaNova: 'AUSENTE' });
    });

    it('registra falta justificada', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Falta Justificada E2E',
      );
      const { aula, aulaAluno } = await criarAulaComAluno(
        academia.id,
        turma.id,
        professor.id,
        userId,
        aluno.id,
        turmaAluno.id,
        diasAtras(2),
      );

      const marcada = await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${aula.id}/alunos/${aulaAluno.id}/presenca`)
        .set('Authorization', `Bearer ${token}`)
        .send({ presenca: 'JUSTIFICADA' })
        .expect(200);
      expect(marcada.body.presenca).toBe('JUSTIFICADA');
    });

    it('não altera Aula, Turma, Recorrencia nem TurmaAluno', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Invariante Frequencia E2E',
      );
      const { aula, aulaAluno } = await criarAulaComAluno(
        academia.id,
        turma.id,
        professor.id,
        userId,
        aluno.id,
        turmaAluno.id,
        diasAtras(1),
      );

      const aulaAntes = await prisma.aula.findUniqueOrThrow({ where: { id: aula.id } });
      const turmaAntes = await prisma.turma.findUniqueOrThrow({ where: { id: turma.id } });
      const turmaAlunoAntes = await prisma.turmaAluno.findUniqueOrThrow({ where: { id: turmaAluno.id } });

      await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${aula.id}/alunos/${aulaAluno.id}/presenca`)
        .set('Authorization', `Bearer ${token}`)
        .send({ presenca: 'PRESENTE' })
        .expect(200);

      const aulaDepois = await prisma.aula.findUniqueOrThrow({ where: { id: aula.id } });
      const turmaDepois = await prisma.turma.findUniqueOrThrow({ where: { id: turma.id } });
      const turmaAlunoDepois = await prisma.turmaAluno.findUniqueOrThrow({ where: { id: turmaAluno.id } });

      expect(aulaDepois.updatedAt.getTime()).toBe(aulaAntes.updatedAt.getTime());
      expect(aulaDepois.status).toBe(aulaAntes.status);
      expect(turmaDepois.updatedAt.getTime()).toBe(turmaAntes.updatedAt.getTime());
      expect(turmaAlunoDepois.updatedAt.getTime()).toBe(turmaAlunoAntes.updatedAt.getTime());
    });
  });

  describe('Bloqueios', () => {
    it('aula cancelada -> 400', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Presenca Cancelada E2E',
      );
      const { aula, aulaAluno } = await criarAulaComAluno(
        academia.id,
        turma.id,
        professor.id,
        userId,
        aluno.id,
        turmaAluno.id,
        diasAtras(1),
        'CANCELADA',
      );

      await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${aula.id}/alunos/${aulaAluno.id}/presenca`)
        .set('Authorization', `Bearer ${token}`)
        .send({ presenca: 'PRESENTE' })
        .expect(400);
    });

    it('aula futura -> 400', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Presenca Futura E2E',
      );
      const { aula, aulaAluno } = await criarAulaComAluno(
        academia.id,
        turma.id,
        professor.id,
        userId,
        aluno.id,
        turmaAluno.id,
        diasAFrente(3),
      );

      await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${aula.id}/alunos/${aulaAluno.id}/presenca`)
        .set('Authorization', `Bearer ${token}`)
        .send({ presenca: 'PRESENTE' })
        .expect(400);
    });

    it('aula de hoje ainda não é considerada realizada -> 400', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Presenca Hoje E2E',
      );
      const { aula, aulaAluno } = await criarAulaComAluno(
        academia.id,
        turma.id,
        professor.id,
        userId,
        aluno.id,
        turmaAluno.id,
        diasAtras(0),
      );

      await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${aula.id}/alunos/${aulaAluno.id}/presenca`)
        .set('Authorization', `Bearer ${token}`)
        .send({ presenca: 'PRESENTE' })
        .expect(400);
    });

    it('aulaId inexistente -> 404', async () => {
      const { token } = await cenarioBase('Academia Aula Inexistente Frequencia E2E');

      await request(app.getHttpServer())
        .patch('/api/agenda/aulas/00000000-0000-4000-8000-000000000099/alunos/00000000-0000-4000-8000-000000000098/presenca')
        .set('Authorization', `Bearer ${token}`)
        .send({ presenca: 'PRESENTE' })
        .expect(404);
    });

    it('id de AulaAluno de outra aula -> 404', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia AulaAluno Cross Aula E2E',
      );
      const primeira = await criarAulaComAluno(
        academia.id,
        turma.id,
        professor.id,
        userId,
        aluno.id,
        turmaAluno.id,
        diasAtras(1),
      );
      const segunda = await criarAulaComAluno(
        academia.id,
        turma.id,
        professor.id,
        userId,
        aluno.id,
        turmaAluno.id,
        diasAtras(2),
      );
      void segunda;

      await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${primeira.aula.id}/alunos/${segunda.aulaAluno.id}/presenca`)
        .set('Authorization', `Bearer ${token}`)
        .send({ presenca: 'PRESENTE' })
        .expect(404);
    });
  });

  describe('Consulta por Aula', () => {
    it('lista os alunos de uma aula com a presença de cada um', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Consulta Por Aula E2E',
      );
      const { aula, aulaAluno } = await criarAulaComAluno(
        academia.id,
        turma.id,
        professor.id,
        userId,
        aluno.id,
        turmaAluno.id,
        diasAtras(1),
      );

      const lista = await request(app.getHttpServer())
        .get(`/api/agenda/aulas/${aula.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(lista.body).toHaveLength(1);
      expect(lista.body[0].id).toBe(aulaAluno.id);
      expect(lista.body[0].alunoNome).toBe(aluno.nome);
      expect(lista.body[0].presenca).toBeNull();
    });
  });

  describe('Consulta por Aluno', () => {
    it('lista o histórico de frequência do aluno, paginado e ordenado por data desc', async () => {
      const { academia, token, professor, userId, turma, aluno, turmaAluno } = await cenarioBase(
        'Academia Consulta Por Aluno E2E',
      );
      const antiga = await criarAulaComAluno(
        academia.id,
        turma.id,
        professor.id,
        userId,
        aluno.id,
        turmaAluno.id,
        diasAtras(10),
      );
      const recente = await criarAulaComAluno(
        academia.id,
        turma.id,
        professor.id,
        userId,
        aluno.id,
        turmaAluno.id,
        diasAtras(1),
      );
      await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${recente.aula.id}/alunos/${recente.aulaAluno.id}/presenca`)
        .set('Authorization', `Bearer ${token}`)
        .send({ presenca: 'PRESENTE' })
        .expect(200);

      const historico = await request(app.getHttpServer())
        .get(`/api/agenda/alunos/${aluno.id}/frequencia`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(historico.body.total).toBe(2);
      expect(historico.body.items[0].aulaId).toBe(recente.aula.id);
      expect(historico.body.items[0].presenca).toBe('PRESENTE');
      expect(historico.body.items[0].turmaNome).toBe(turma.nome);
      expect(historico.body.items[1].aulaId).toBe(antiga.aula.id);
      expect(historico.body.items[1].presenca).toBeNull();
    });

    it('alunoId inexistente -> 404', async () => {
      const { token } = await cenarioBase('Academia Aluno Inexistente Frequencia E2E');

      await request(app.getHttpServer())
        .get('/api/agenda/alunos/00000000-0000-4000-8000-000000000099/frequencia')
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê nem registra presença de aula da academia B', async () => {
      const cenarioA = await cenarioBase('Academia Isolamento Frequencia A E2E');
      const cenarioB = await cenarioBase('Academia Isolamento Frequencia B E2E');
      const { aula, aulaAluno } = await criarAulaComAluno(
        cenarioB.academia.id,
        cenarioB.turma.id,
        cenarioB.professor.id,
        cenarioB.userId,
        cenarioB.aluno.id,
        cenarioB.turmaAluno.id,
        diasAtras(1),
      );

      await request(app.getHttpServer())
        .get(`/api/agenda/aulas/${aula.id}/alunos`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(404);

      await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${aula.id}/alunos/${aulaAluno.id}/presenca`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({ presenca: 'PRESENTE' })
        .expect(404);

      await request(app.getHttpServer())
        .get(`/api/agenda/alunos/${cenarioB.aluno.id}/frequencia`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(404);
    });
  });
});
