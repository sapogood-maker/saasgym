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

/// Cobre o cascade de "encerrar vínculo" (docs/32 — auditoria de ciclo de
/// vida do Aluno): arquivar (`status = INATIVO`) ou remover (soft delete)
/// um Aluno precisa, na mesma operação, cancelar a Matrícula ativa,
/// desmatricular de Turmas, tirar de aulas futuras já geradas e rejeitar
/// reposição pendente — sem apagar nada do histórico.
describe('Encerramento de vínculo do Aluno (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string) {
    const email = `${role.toLowerCase()}-encerra-${Date.now()}-${Math.random()}@example.com`;
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

  function diasAFrente(dias: number): Date {
    const data = new Date();
    data.setUTCDate(data.getUTCDate() + dias);
    return new Date(Date.UTC(data.getUTCFullYear(), data.getUTCMonth(), data.getUTCDate()));
  }

  function diasAtras(dias: number): Date {
    const data = new Date();
    data.setUTCDate(data.getUTCDate() - dias);
    return new Date(Date.UTC(data.getUTCFullYear(), data.getUTCMonth(), data.getUTCDate()));
  }

  async function criarAula(
    academiaId: string,
    turmaId: string,
    professorId: string,
    userId: string,
    data: Date,
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
        capacidadeMaxima: null,
        status: AulaStatus.AGENDADA,
        createdByUserId: userId,
      },
    });
  }

  async function criarAulaAluno(
    academiaId: string,
    aulaId: string,
    alunoId: string,
    turmaAlunoId: string | null,
    presenca: PresencaStatus | null = null,
  ) {
    return prisma.aulaAluno.create({
      data: { academiaId, aulaId, alunoId, turmaAlunoId, tipo: 'MATRICULADO', presenca },
    });
  }

  async function cenarioCompleto(nomeAcademia: string) {
    const academia = await createAcademiaFixture(prisma, { nome: nomeAcademia });
    const { token, userId } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    const modalidade = await createModalidadeFixture(prisma, academia.id);
    const professor = await createProfessorFixture(prisma, academia.id);
    const plano = await createPlanoFixture(prisma, academia.id);

    const turma = await request(app.getHttpServer())
      .post('/api/agenda/turmas')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Turma Encerramento', modalidadeId: modalidade.id, professorId: professor.id })
      .expect(201);

    const aluno = await createAlunoFixture(prisma, academia.id);
    const matricula = await createMatriculaFixture(prisma, academia.id, aluno.id, plano.id, userId);

    const turmaAluno = await request(app.getHttpServer())
      .post(`/api/agenda/turmas/${turma.body.id}/alunos`)
      .set('Authorization', `Bearer ${token}`)
      .send({ alunoId: aluno.id })
      .expect(201);

    // Aula futura já gerada, com o aluno matriculado nela (simula o que
    // AulasService.gerar() já teria criado a partir do TurmaAluno acima).
    const aulaFutura = await criarAula(
      academia.id,
      turma.body.id,
      professor.id,
      userId,
      diasAFrente(5),
    );
    await criarAulaAluno(academia.id, aulaFutura.id, aluno.id, turmaAluno.body.id);

    // Aula passada com falta, origem elegível pra uma reposição pendente.
    const aulaPassada = await criarAula(
      academia.id,
      turma.body.id,
      professor.id,
      userId,
      diasAtras(3),
    );
    const aulaAlunoOrigem = await criarAulaAluno(
      academia.id,
      aulaPassada.id,
      aluno.id,
      turmaAluno.body.id,
      PresencaStatus.AUSENTE,
    );
    const reposicao = await request(app.getHttpServer())
      .post('/api/agenda/solicitacoes-reposicao')
      .set('Authorization', `Bearer ${token}`)
      .send({ aulaAlunoOrigemId: aulaAlunoOrigem.id })
      .expect(201);

    return {
      academia,
      token,
      userId,
      professor,
      turma: turma.body,
      aluno,
      matricula,
      turmaAluno: turmaAluno.body,
      aulaFutura,
      aulaPassada,
      aulaAlunoOrigem,
      reposicao: reposicao.body,
    };
  }

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('arquivar (status = INATIVO) encerra matrícula, turma, aula futura e reposição pendente — sem apagar histórico', async () => {
    const cenario = await cenarioCompleto('Academia Encerramento Arquivar E2E');

    await request(app.getHttpServer())
      .patch(`/api/alunos/${cenario.aluno.id}/status`)
      .set('Authorization', `Bearer ${cenario.token}`)
      .send({ status: 'INATIVO' })
      .expect(200);

    // 1) Matrícula ATIVA foi cancelada, com o motivo automático — nunca
    //    apagada (deletedAt continua null).
    const matriculaDb = await prisma.matricula.findUniqueOrThrow({
      where: { id: cenario.matricula.id },
    });
    expect(matriculaDb.status).toBe('CANCELADA');
    expect(matriculaDb.motivoCancelamento).toBe('ALUNO_ARQUIVADO');
    expect(matriculaDb.deletedAt).toBeNull();

    // 2) TurmaAluno virou INATIVO (mesmo efeito de "sair da turma") — não
    //    foi removido nem apagado.
    const turmaAlunoDb = await prisma.turmaAluno.findUniqueOrThrow({
      where: { id: cenario.turmaAluno.id },
    });
    expect(turmaAlunoDb.status).toBe('INATIVO');
    expect(turmaAlunoDb.deletedAt).toBeNull();

    // 3) A aula FUTURA perdeu o vínculo (soft delete) — ocupação cai a
    //    zero. A linha em si continua no banco (histórico preservado).
    const aulaFuturaDetalhe = await request(app.getHttpServer())
      .get(`/api/agenda/aulas/${cenario.aulaFutura.id}`)
      .set('Authorization', `Bearer ${cenario.token}`)
      .expect(200);
    expect(aulaFuturaDetalhe.body.totalAlunos).toBe(0);
    const aulaAlunoFuturoDb = await prisma.aulaAluno.findFirstOrThrow({
      where: { aulaId: cenario.aulaFutura.id, alunoId: cenario.aluno.id },
    });
    expect(aulaAlunoFuturoDb.deletedAt).not.toBeNull();

    // 4) A reposição PENDENTE foi rejeitada automaticamente.
    const reposicaoDb = await prisma.solicitacaoReposicao.findUniqueOrThrow({
      where: { id: cenario.reposicao.id },
    });
    expect(reposicaoDb.status).toBe('REJEITADA');
    expect(reposicaoDb.motivoRejeicao).toContain('arquivado');

    // 5) Histórico preservado: a aula PASSADA com a falta original continua
    //    intacta, presença e tudo — nunca tocada pelo cascade.
    const aulaAlunoOrigemDb = await prisma.aulaAluno.findUniqueOrThrow({
      where: { id: cenario.aulaAlunoOrigem.id },
    });
    expect(aulaAlunoOrigemDb.deletedAt).toBeNull();
    expect(aulaAlunoOrigemDb.presenca).toBe('AUSENTE');

    // 6) Não é possível matricular o aluno arquivado de novo.
    await request(app.getHttpServer())
      .post('/api/matriculas')
      .set('Authorization', `Bearer ${cenario.token}`)
      .send({
        alunoId: cenario.aluno.id,
        planoId: cenario.matricula.planoId,
        dataInicio: '2026-08-01',
      })
      .expect(400);

    // 7) Não é possível solicitar uma NOVA reposição pra esse aluno,
    //    mesmo a partir de outra falta real no passado.
    const outraAulaPassada = await criarAula(
      cenario.academia.id,
      cenario.turma.id,
      cenario.professor.id,
      cenario.userId,
      diasAtras(1),
    );
    const outraOrigem = await criarAulaAluno(
      cenario.academia.id,
      outraAulaPassada.id,
      cenario.aluno.id,
      cenario.turmaAluno.id,
      PresencaStatus.AUSENTE,
    );
    await request(app.getHttpServer())
      .post('/api/agenda/solicitacoes-reposicao')
      .set('Authorization', `Bearer ${cenario.token}`)
      .send({ aulaAlunoOrigemId: outraOrigem.id })
      .expect(400);
  });

  it('remover (soft delete) também encerra o vínculo, sem apagar matrícula/turma', async () => {
    const cenario = await cenarioCompleto('Academia Encerramento Remover E2E');

    await request(app.getHttpServer())
      .delete(`/api/alunos/${cenario.aluno.id}`)
      .set('Authorization', `Bearer ${cenario.token}`)
      .expect(204);

    const matriculaDb = await prisma.matricula.findUniqueOrThrow({
      where: { id: cenario.matricula.id },
    });
    expect(matriculaDb.status).toBe('CANCELADA');
    expect(matriculaDb.motivoCancelamento).toBe('ALUNO_ARQUIVADO');
    expect(matriculaDb.deletedAt).toBeNull();

    const turmaAlunoDb = await prisma.turmaAluno.findUniqueOrThrow({
      where: { id: cenario.turmaAluno.id },
    });
    expect(turmaAlunoDb.status).toBe('INATIVO');

    const aulaAlunoFuturoDb = await prisma.aulaAluno.findFirstOrThrow({
      where: { aulaId: cenario.aulaFutura.id, alunoId: cenario.aluno.id },
    });
    expect(aulaAlunoFuturoDb.deletedAt).not.toBeNull();

    const reposicaoDb = await prisma.solicitacaoReposicao.findUniqueOrThrow({
      where: { id: cenario.reposicao.id },
    });
    expect(reposicaoDb.status).toBe('REJEITADA');

    // Aluno em si: soft delete, nunca uma linha apagada.
    const alunoDb = await prisma.aluno.findUniqueOrThrow({ where: { id: cenario.aluno.id } });
    expect(alunoDb.deletedAt).not.toBeNull();
  });

  it('arquivar um aluno sem nenhum vínculo ativo não falha (idempotente, zero efeito colateral)', async () => {
    const academia = await createAcademiaFixture(prisma, {
      nome: 'Academia Encerramento Vazio E2E',
    });
    const { token } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    const aluno = await createAlunoFixture(prisma, academia.id);

    await request(app.getHttpServer())
      .patch(`/api/alunos/${aluno.id}/status`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'INATIVO' })
      .expect(200);

    // Rodar de novo (aluno já INATIVO) — continua sem erro, sem efeito.
    await request(app.getHttpServer())
      .patch(`/api/alunos/${aluno.id}/status`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'INATIVO' })
      .expect(200);
  });
});
