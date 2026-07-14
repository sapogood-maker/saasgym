import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import {
  createAcademiaFixture,
  createModalidadeFixture,
  createProfessorFixture,
} from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

const SENHA = 'SenhaForte123';

describe('Recorrencias (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string): Promise<string> {
    const email = `${role.toLowerCase()}-recorrencias-${Date.now()}-${Math.random()}@example.com`;
    await prisma.user.create({
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
    return res.body.accessToken;
  }

  /// Academia + token + turma real (com modalidade/professor), pronta pra
  /// criar Recorrência — mesmo padrão de cenarioBase já usado em Turmas.
  async function cenarioBase(nomeAcademia: string) {
    const academia = await createAcademiaFixture(prisma, { nome: nomeAcademia });
    const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    const modalidade = await createModalidadeFixture(prisma, academia.id);
    const professor = await createProfessorFixture(prisma, academia.id);

    const turma = await request(app.getHttpServer())
      .post('/api/agenda/turmas')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Turma Base', modalidadeId: modalidade.id, professorId: professor.id })
      .expect(201);

    return { academia, token, modalidade, professor, turma: turma.body };
  }

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('sem token -> 401', async () => {
    const { turma } = await cenarioBase('Academia Recorrencia Sem Token E2E');
    await request(app.getHttpServer())
      .get(`/api/agenda/turmas/${turma.id}/recorrencias`)
      .expect(401);
  });

  it('PROFESSOR não tem acesso (403)', async () => {
    const { turma, academia } = await cenarioBase('Academia Recorrencia Professor Sem Acesso E2E');
    const tokenProfessor = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    await request(app.getHttpServer())
      .get(`/api/agenda/turmas/${turma.id}/recorrencias`)
      .set('Authorization', `Bearer ${tokenProfessor}`)
      .expect(403);
  });

  describe('CRUD', () => {
    it('ACADEMIA_ADMIN cria (SEMANAL), lista, edita e remove uma recorrência', async () => {
      const { academia, token, turma } = await cenarioBase('Academia CRUD Recorrencia E2E');

      const criada = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          tipo: 'SEMANAL',
          diaSemana: 1,
          horaInicio: '07:00',
          duracaoMinutos: 60,
          dataInicioVigencia: '2026-08-01',
        })
        .expect(201);
      expect(criada.body.turmaId).toBe(turma.id);
      expect(criada.body.diaSemana).toBe(1);
      expect(criada.body.ativo).toBe(true);
      expect(criada.body.professorNome).toBeNull();

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'RECORRENCIA_CREATED', academiaId: academia.id },
      });
      expect(auditEntry).not.toBeNull();

      const lista = await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(lista.body).toHaveLength(1);
      expect(lista.body[0].id).toBe(criada.body.id);

      const editada = await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${turma.id}/recorrencias/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ horaInicio: '08:00' })
        .expect(200);
      expect(editada.body.horaInicio).toBe('08:00');

      const inativada = await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${turma.id}/recorrencias/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ ativo: false })
        .expect(200);
      expect(inativada.body.ativo).toBe(false);

      await request(app.getHttpServer())
        .delete(`/api/agenda/turmas/${turma.id}/recorrencias/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(204);

      const listaVazia = await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(listaVazia.body).toHaveLength(0);
    });

    it('cria recorrência MENSAL com professor override', async () => {
      const { token, turma, professor } = await cenarioBase('Academia Recorrencia Mensal E2E');

      const criada = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          tipo: 'MENSAL',
          diaDoMes: 15,
          horaInicio: '19:00',
          duracaoMinutos: 90,
          professorId: professor.id,
          dataInicioVigencia: '2026-08-01',
        })
        .expect(201);
      expect(criada.body.diaDoMes).toBe(15);
      expect(criada.body.professorId).toBe(professor.id);
      expect(criada.body.professorNome).toBe(professor.nome);
    });

    it('cria recorrência INTERVALADA', async () => {
      const { token, turma } = await cenarioBase('Academia Recorrencia Intervalada E2E');

      const criada = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          tipo: 'INTERVALADA',
          intervaloDias: 14,
          horaInicio: '18:30',
          duracaoMinutos: 45,
          dataInicioVigencia: '2026-08-01',
        })
        .expect(201);
      expect(criada.body.intervaloDias).toBe(14);
    });

    it('SEMANAL sem diaSemana -> 400', async () => {
      const { token, turma } = await cenarioBase('Academia Semanal Sem Dia E2E');

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'SEMANAL', horaInicio: '07:00', duracaoMinutos: 60, dataInicioVigencia: '2026-08-01' })
        .expect(400);
    });

    it('MENSAL sem diaDoMes -> 400', async () => {
      const { token, turma } = await cenarioBase('Academia Mensal Sem Dia E2E');

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'MENSAL', horaInicio: '07:00', duracaoMinutos: 60, dataInicioVigencia: '2026-08-01' })
        .expect(400);
    });

    it('INTERVALADA sem intervaloDias -> 400', async () => {
      const { token, turma } = await cenarioBase('Academia Intervalada Sem Dias E2E');

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'INTERVALADA', horaInicio: '07:00', duracaoMinutos: 60, dataInicioVigencia: '2026-08-01' })
        .expect(400);
    });

    it('horaInicio em formato inválido -> 400', async () => {
      const { token, turma } = await cenarioBase('Academia Hora Invalida E2E');

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          tipo: 'SEMANAL',
          diaSemana: 1,
          horaInicio: '7:00',
          duracaoMinutos: 60,
          dataInicioVigencia: '2026-08-01',
        })
        .expect(400);
    });

    it('turmaId inexistente -> 404', async () => {
      const { token } = await cenarioBase('Academia Turma Inexistente Recorrencia E2E');

      await request(app.getHttpServer())
        .post('/api/agenda/turmas/00000000-0000-4000-8000-000000000099/recorrencias')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'SEMANAL', diaSemana: 1, horaInicio: '07:00', duracaoMinutos: 60, dataInicioVigencia: '2026-08-01' })
        .expect(404);
    });

    it('professorId override inexistente -> 404', async () => {
      const { token, turma } = await cenarioBase('Academia Professor Override Inexistente E2E');

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          tipo: 'SEMANAL',
          diaSemana: 1,
          horaInicio: '07:00',
          duracaoMinutos: 60,
          professorId: '00000000-0000-4000-8000-000000000099',
          dataInicioVigencia: '2026-08-01',
        })
        .expect(404);
    });

    it('professor de outra academia não pode ser referenciado como override (404)', async () => {
      const cenarioA = await cenarioBase('Academia Recorrencia Cross Tenant A E2E');
      const cenarioB = await cenarioBase('Academia Recorrencia Cross Tenant B E2E');

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${cenarioA.turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({
          tipo: 'SEMANAL',
          diaSemana: 1,
          horaInicio: '07:00',
          duracaoMinutos: 60,
          professorId: cenarioB.professor.id,
          dataInicioVigencia: '2026-08-01',
        })
        .expect(404);
    });

    it('uma turma pode ter múltiplas recorrências independentes (invariante 2)', async () => {
      const { token, turma } = await cenarioBase('Academia Multiplas Recorrencias E2E');

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'SEMANAL', diaSemana: 1, horaInicio: '07:00', duracaoMinutos: 60, dataInicioVigencia: '2026-08-01' })
        .expect(201);
      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'SEMANAL', diaSemana: 3, horaInicio: '07:00', duracaoMinutos: 60, dataInicioVigencia: '2026-08-01' })
        .expect(201);
      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'SEMANAL', diaSemana: 6, horaInicio: '10:00', duracaoMinutos: 60, dataInicioVigencia: '2026-08-01' })
        .expect(201);

      const lista = await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(lista.body).toHaveLength(3);
    });

    it('mudar tipo sem enviar o novo campo obrigatório -> 400 (consistência no update)', async () => {
      const { token, turma } = await cenarioBase('Academia Update Tipo Inconsistente E2E');

      const criada = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'SEMANAL', diaSemana: 1, horaInicio: '07:00', duracaoMinutos: 60, dataInicioVigencia: '2026-08-01' })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${turma.id}/recorrencias/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'MENSAL' })
        .expect(400);
    });

    it('id inexistente -> 404', async () => {
      const { token, turma } = await cenarioBase('Academia 404 Recorrencia E2E');

      await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${turma.id}/recorrencias/00000000-0000-0000-0000-000000000099`)
        .set('Authorization', `Bearer ${token}`)
        .send({ horaInicio: '08:00' })
        .expect(404);
    });
  });

  describe('Invariante 1 — Recorrência pertence exclusivamente à Turma', () => {
    it('recorrência de uma turma não pode ser editada/removida através de outra turma', async () => {
      const { token, turma: turmaA } = await cenarioBase('Academia Invariante Turma A E2E');
      const { turma: turmaB } = await cenarioBase('Academia Invariante Turma B E2E');

      const recorrenciaA = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turmaA.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'SEMANAL', diaSemana: 1, horaInicio: '07:00', duracaoMinutos: 60, dataInicioVigencia: '2026-08-01' })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${turmaB.id}/recorrencias/${recorrenciaA.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ horaInicio: '08:00' })
        .expect(404);

      await request(app.getHttpServer())
        .delete(`/api/agenda/turmas/${turmaB.id}/recorrencias/${recorrenciaA.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê, não edita e não deleta recorrência da academia B', async () => {
      const cenarioA = await cenarioBase('Academia Isolamento Recorrencia A E2E');
      const cenarioB = await cenarioBase('Academia Isolamento Recorrencia B E2E');

      const recorrenciaB = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${cenarioB.turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${cenarioB.token}`)
        .send({ tipo: 'SEMANAL', diaSemana: 1, horaInicio: '07:00', duracaoMinutos: 60, dataInicioVigencia: '2026-08-01' })
        .expect(201);

      await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${cenarioB.turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(404);

      await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${cenarioB.turma.id}/recorrencias/${recorrenciaB.body.id}`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({ horaInicio: '08:00' })
        .expect(404);

      await request(app.getHttpServer())
        .delete(`/api/agenda/turmas/${cenarioB.turma.id}/recorrencias/${recorrenciaB.body.id}`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(404);
    });
  });

  describe('Soft delete', () => {
    it('DELETE não remove fisicamente — some da listagem mas continua no banco com deletedAt', async () => {
      const { academia, token, turma } = await cenarioBase('Academia Soft Delete Recorrencia E2E');

      const criada = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/recorrencias`)
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'SEMANAL', diaSemana: 1, horaInicio: '07:00', duracaoMinutos: 60, dataInicioVigencia: '2026-08-01' })
        .expect(201);

      await request(app.getHttpServer())
        .delete(`/api/agenda/turmas/${turma.id}/recorrencias/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(204);

      const linhaNoBanco = await prisma.recorrencia.findUnique({ where: { id: criada.body.id } });
      expect(linhaNoBanco).not.toBeNull();
      expect(linhaNoBanco?.deletedAt).not.toBeNull();

      const deleteAudit = await prisma.auditLog.findFirst({
        where: { action: 'RECORRENCIA_DELETED', academiaId: academia.id },
      });
      expect(deleteAudit).not.toBeNull();
    });
  });
});
