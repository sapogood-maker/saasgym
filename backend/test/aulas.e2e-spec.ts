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

describe('Aulas (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string) {
    const email = `${role.toLowerCase()}-aulas-${Date.now()}-${Math.random()}@example.com`;
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

  /// Academia + token + turma real (capacidadeMaxima opcional). Sem
  /// recorrência/aluno ainda — cada teste monta só o que precisa.
  async function cenarioBase(nomeAcademia: string, capacidadeMaxima?: number) {
    const academia = await createAcademiaFixture(prisma, { nome: nomeAcademia });
    const { token, userId } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    const modalidade = await createModalidadeFixture(prisma, academia.id);
    const professor = await createProfessorFixture(prisma, academia.id);
    const plano = await createPlanoFixture(prisma, academia.id);

    const turma = await request(app.getHttpServer())
      .post('/api/agenda/turmas')
      .set('Authorization', `Bearer ${token}`)
      .send({
        nome: 'Turma Base',
        modalidadeId: modalidade.id,
        professorId: professor.id,
        ...(capacidadeMaxima !== undefined ? { capacidadeMaxima } : {}),
      })
      .expect(201);

    return { academia, token, userId, plano, professor, turma: turma.body };
  }

  async function criarRecorrencia(
    token: string,
    turmaId: string,
    overrides: Record<string, unknown> = {},
  ) {
    const res = await request(app.getHttpServer())
      .post(`/api/agenda/turmas/${turmaId}/recorrencias`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        tipo: 'SEMANAL',
        diaSemana: 1,
        horaInicio: '07:00',
        duracaoMinutos: 60,
        dataInicioVigencia: '2026-08-01',
        ...overrides,
      })
      .expect(201);
    return res.body;
  }

  async function inscreverAluno(
    academiaId: string,
    planoId: string,
    userId: string,
    token: string,
    turmaId: string,
  ) {
    const aluno = await createAlunoFixture(prisma, academiaId);
    await createMatriculaFixture(prisma, academiaId, aluno.id, planoId, userId);
    const inscrito = await request(app.getHttpServer())
      .post(`/api/agenda/turmas/${turmaId}/alunos`)
      .set('Authorization', `Bearer ${token}`)
      .send({ alunoId: aluno.id })
      .expect(201);
    return { aluno, turmaAluno: inscrito.body };
  }

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('sem token -> 401', async () => {
    const { turma } = await cenarioBase('Academia Aulas Sem Token E2E');
    await request(app.getHttpServer()).get(`/api/agenda/turmas/${turma.id}/aulas`).expect(401);
  });

  it('PROFESSOR não tem acesso (403)', async () => {
    const { turma, academia } = await cenarioBase('Academia Aulas Professor Sem Acesso E2E');
    const { token: tokenProfessor } = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    await request(app.getHttpServer())
      .get(`/api/agenda/turmas/${turma.id}/aulas`)
      .set('Authorization', `Bearer ${tokenProfessor}`)
      .expect(403);
  });

  describe('Geração — SEMANAL', () => {
    it('gera uma aula por semana, com snapshot correto de horário/professor/capacidade', async () => {
      const { academia, token, turma, professor } = await cenarioBase(
        'Academia Geracao Semanal E2E',
        15,
      );
      await criarRecorrencia(token, turma.id, { diaSemana: 1, horaInicio: '07:00', duracaoMinutos: 60 });

      const resultado = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/aulas/gerar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ dataInicio: '2026-08-01', dataFim: '2026-08-31' })
        .expect(201);
      // Segundas-feiras de agosto/2026: 3, 10, 17, 24, 31 => 5 aulas.
      expect(resultado.body).toEqual({ geradas: 5, jaExistentes: 0 });

      const lista = await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${turma.id}/aulas`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(lista.body.total).toBe(5);
      const primeira = lista.body.items[0];
      expect(primeira.data.slice(0, 10)).toBe('2026-08-03');
      expect(primeira.horaInicio).toBe('07:00');
      expect(primeira.duracaoMinutos).toBe(60);
      expect(primeira.professorId).toBe(professor.id);
      expect(primeira.professorNome).toBe(professor.nome);
      expect(primeira.capacidadeMaxima).toBe(15);
      expect(primeira.status).toBe('AGENDADA');
      expect(primeira.totalAlunos).toBe(0);

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'AULA_GERADA', academiaId: academia.id },
      });
      expect(auditEntry?.metadata).toMatchObject({ geradas: 5, jaExistentes: 0 });
    });

    it('professor override da Recorrência prevalece sobre o titular da Turma', async () => {
      const { token, turma } = await cenarioBase('Academia Professor Override Aula E2E');
      const outroProfessor = await createProfessorFixture(prisma, (await prisma.turma.findUniqueOrThrow({ where: { id: turma.id } })).academiaId);
      await criarRecorrencia(token, turma.id, { professorId: outroProfessor.id });

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/aulas/gerar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ dataInicio: '2026-08-01', dataFim: '2026-08-31' })
        .expect(201);

      const lista = await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${turma.id}/aulas`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(lista.body.items[0].professorId).toBe(outroProfessor.id);
    });
  });

  describe('Geração — MENSAL e INTERVALADA', () => {
    it('gera uma aula por mês (MENSAL)', async () => {
      const { token, turma } = await cenarioBase('Academia Geracao Mensal E2E');
      await criarRecorrencia(token, turma.id, {
        tipo: 'MENSAL',
        diaSemana: undefined,
        diaDoMes: 15,
        horaInicio: '19:00',
        duracaoMinutos: 90,
      });

      const resultado = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/aulas/gerar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ dataInicio: '2026-08-01', dataFim: '2026-10-31' })
        .expect(201);
      expect(resultado.body.geradas).toBe(3);
    });

    it('gera aulas a cada N dias (INTERVALADA)', async () => {
      const { token, turma } = await cenarioBase('Academia Geracao Intervalada E2E');
      await criarRecorrencia(token, turma.id, {
        tipo: 'INTERVALADA',
        diaSemana: undefined,
        intervaloDias: 14,
        horaInicio: '18:30',
        duracaoMinutos: 45,
      });

      const resultado = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/aulas/gerar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ dataInicio: '2026-08-01', dataFim: '2026-09-30' })
        .expect(201);
      // 1/ago, 15/ago, 29/ago, 12/set, 26/set => 5 aulas.
      expect(resultado.body.geradas).toBe(5);
    });
  });

  describe('Feriado', () => {
    it('pula datas com Feriado cadastrado', async () => {
      const { token, turma } = await cenarioBase('Academia Feriado Geracao E2E');
      await criarRecorrencia(token, turma.id, { diaSemana: 1 });
      await request(app.getHttpServer())
        .post('/api/agenda/feriados')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Feriado de Teste', data: '2026-08-10' })
        .expect(201);

      const resultado = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/aulas/gerar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ dataInicio: '2026-08-01', dataFim: '2026-08-31' })
        .expect(201);
      // 5 segundas-feiras menos 1 (10/ago, feriado) => 4.
      expect(resultado.body.geradas).toBe(4);
    });
  });

  describe('AulaAluno — população automática', () => {
    it('cria AulaAluno(MATRICULADO) para cada TurmaAluno ativo no momento da geração', async () => {
      const { academia, token, userId, plano, turma } = await cenarioBase(
        'Academia AulaAluno Populacao E2E',
      );
      await criarRecorrencia(token, turma.id, { diaSemana: 1 });
      const { aluno: alunoAtivo, turmaAluno } = await inscreverAluno(
        academia.id,
        plano.id,
        userId,
        token,
        turma.id,
      );
      const { turmaAluno: turmaAlunoInativo } = await inscreverAluno(
        academia.id,
        plano.id,
        userId,
        token,
        turma.id,
      );
      // Segundo aluno sai da turma antes da geração — não deve aparecer em AulaAluno.
      await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${turma.id}/alunos/${turmaAlunoInativo.id}/status`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'INATIVO' })
        .expect(200);

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/aulas/gerar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ dataInicio: '2026-08-01', dataFim: '2026-08-31' })
        .expect(201);

      const lista = await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${turma.id}/aulas`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      for (const aulaResumo of lista.body.items) {
        expect(aulaResumo.totalAlunos).toBe(1);
      }

      const primeiraAula = await prisma.aula.findFirst({ where: { turmaId: turma.id }, orderBy: { data: 'asc' } });
      const aulaAlunos = await prisma.aulaAluno.findMany({ where: { aulaId: primeiraAula!.id } });
      expect(aulaAlunos).toHaveLength(1);
      expect(aulaAlunos[0].alunoId).toBe(alunoAtivo.id);
      expect(aulaAlunos[0].turmaAlunoId).toBe(turmaAluno.id);
      expect(aulaAlunos[0].tipo).toBe('MATRICULADO');
    });
  });

  describe('Idempotência (invariantes MS6)', () => {
    it('rodar a mesma geração duas vezes não duplica Aula nem AulaAluno, nem altera snapshots', async () => {
      const { academia, token, userId, plano, turma } = await cenarioBase(
        'Academia Idempotencia E2E',
      );
      await criarRecorrencia(token, turma.id, { diaSemana: 1 });
      await inscreverAluno(academia.id, plano.id, userId, token, turma.id);

      const primeira = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/aulas/gerar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ dataInicio: '2026-08-01', dataFim: '2026-08-31' })
        .expect(201);
      expect(primeira.body).toEqual({ geradas: 5, jaExistentes: 0 });

      const antes = await prisma.aula.findMany({ where: { turmaId: turma.id }, orderBy: { data: 'asc' } });
      const aulaAlunosAntes = await prisma.aulaAluno.count({ where: { aula: { turmaId: turma.id } } });

      const segunda = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/aulas/gerar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ dataInicio: '2026-08-01', dataFim: '2026-08-31' })
        .expect(201);
      expect(segunda.body).toEqual({ geradas: 0, jaExistentes: 5 });

      const depois = await prisma.aula.findMany({ where: { turmaId: turma.id }, orderBy: { data: 'asc' } });
      const aulaAlunosDepois = await prisma.aulaAluno.count({ where: { aula: { turmaId: turma.id } } });

      expect(depois).toHaveLength(antes.length);
      expect(aulaAlunosDepois).toBe(aulaAlunosAntes);
      depois.forEach((aula, i) => {
        expect(aula.id).toBe(antes[i].id);
        expect(aula.horaInicio).toBe(antes[i].horaInicio);
        expect(aula.professorId).toBe(antes[i].professorId);
        expect(aula.updatedAt.getTime()).toBe(antes[i].updatedAt.getTime());
      });
    });

    it('gerar sobre um período parcialmente sobreposto só cria as datas novas', async () => {
      const { token, turma } = await cenarioBase('Academia Geracao Parcial E2E');
      await criarRecorrencia(token, turma.id, { diaSemana: 1 });

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/aulas/gerar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ dataInicio: '2026-08-01', dataFim: '2026-08-15' })
        .expect(201);

      const segunda = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/aulas/gerar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ dataInicio: '2026-08-01', dataFim: '2026-08-31' })
        .expect(201);
      // 3/ago e 10/ago já existiam; 17/ago, 24/ago, 31/ago são novas.
      expect(segunda.body).toEqual({ geradas: 3, jaExistentes: 2 });
    });
  });

  describe('Invariante 1 — Aula já gerada não é modificada retroativamente', () => {
    it('trocar o professor titular da Turma depois de gerar não altera aulas já geradas', async () => {
      const { token, turma, professor } = await cenarioBase('Academia Nao Retroage E2E');
      await criarRecorrencia(token, turma.id, { diaSemana: 1 });
      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/aulas/gerar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ dataInicio: '2026-08-01', dataFim: '2026-08-31' })
        .expect(201);

      const novoProfessor = await createProfessorFixture(
        prisma,
        (await prisma.turma.findUniqueOrThrow({ where: { id: turma.id } })).academiaId,
      );
      await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${turma.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ professorId: novoProfessor.id })
        .expect(200);

      const lista = await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${turma.id}/aulas`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      lista.body.items.forEach((aula: { professorId: string }) => {
        expect(aula.professorId).toBe(professor.id);
      });
    });
  });

  describe('Validação', () => {
    it('dataInicio depois de dataFim -> 400', async () => {
      const { token, turma } = await cenarioBase('Academia Data Invalida E2E');

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/aulas/gerar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ dataInicio: '2026-08-31', dataFim: '2026-08-01' })
        .expect(400);
    });

    it('turmaId inexistente -> 404', async () => {
      const { token } = await cenarioBase('Academia Turma Inexistente Aula E2E');

      await request(app.getHttpServer())
        .post('/api/agenda/turmas/00000000-0000-4000-8000-000000000099/aulas/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ dataInicio: '2026-08-01', dataFim: '2026-08-31' })
        .expect(404);
    });
  });

  describe('Paginação e filtro de período', () => {
    it('filtra por dataInicio/dataFim e pagina', async () => {
      const { token, turma } = await cenarioBase('Academia Paginacao Aula E2E');
      await criarRecorrencia(token, turma.id, { diaSemana: 1 });
      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/aulas/gerar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ dataInicio: '2026-08-01', dataFim: '2026-08-31' })
        .expect(201);

      const filtrado = await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${turma.id}/aulas?dataInicio=2026-08-11&dataFim=2026-08-20`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(filtrado.body.total).toBe(1);
      expect(filtrado.body.items[0].data.slice(0, 10)).toBe('2026-08-17');

      const paginado = await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${turma.id}/aulas?page=1&pageSize=2`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(paginado.body.items).toHaveLength(2);
      expect(paginado.body.total).toBe(5);
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê nem gera aulas na turma da academia B', async () => {
      const cenarioA = await cenarioBase('Academia Isolamento Aula A E2E');
      const cenarioB = await cenarioBase('Academia Isolamento Aula B E2E');
      await criarRecorrencia(cenarioB.token, cenarioB.turma.id, { diaSemana: 1 });

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${cenarioB.turma.id}/aulas/gerar`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({ dataInicio: '2026-08-01', dataFim: '2026-08-31' })
        .expect(404);

      await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${cenarioB.turma.id}/aulas`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(404);
    });
  });
});
