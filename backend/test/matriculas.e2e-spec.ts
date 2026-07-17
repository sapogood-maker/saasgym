import { randomUUID } from 'node:crypto';
import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import { createAcademiaFixture, createAlunoFixture, createPlanoFixture } from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

const SENHA = 'SenhaForte123';

describe('Matrículas (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string): Promise<string> {
    const email = `${role.toLowerCase()}-matriculas-${Date.now()}-${Math.random()}@example.com`;
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

  /// Monta o par aluno+plano+token necessário pra qualquer teste de
  /// matrícula — extraído porque quase todo teste abaixo precisa dos três.
  async function cenarioBase(nomeAcademia: string) {
    const academia = await createAcademiaFixture(prisma, { nome: nomeAcademia });
    const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    const aluno = await createAlunoFixture(prisma, academia.id);
    const plano = await createPlanoFixture(prisma, academia.id, { valor: 150 });
    return { academia, token, aluno, plano };
  }

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('sem token -> 401', async () => {
    await request(app.getHttpServer()).get('/api/matriculas').expect(401);
  });

  it('SYSTEM_ADMIN (sem academiaId) -> 403 (AcademiaGuard bloqueia)', async () => {
    const senhaHash = await bcrypt.hash(SENHA, 10);
    const email = `sysadmin-matriculas-${Date.now()}@example.com`;
    await prisma.user.create({
      data: { nome: 'Sys Admin', email, senhaHash, role: Role.SYSTEM_ADMIN },
    });
    const token = (
      await request(app.getHttpServer()).post('/api/auth/login').send({ email, password: SENHA })
    ).body.accessToken;

    await request(app.getHttpServer())
      .get('/api/matriculas')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  describe('CRUD e ciclo de vida básico', () => {
    it('ALUNO (sem permissão nenhuma no módulo) -> 403 ao listar', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Aluno Sem Acesso Matricula E2E',
      });
      const token = await criarUsuarioELogar(Role.ALUNO, academia.id);

      await request(app.getHttpServer())
        .get('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .expect(403);
    });

    it('PROFESSOR consegue listar mas não criar (403)', async () => {
      const { academia, aluno, plano } = await cenarioBase(
        'Academia Professor Leitura Matricula E2E',
      );
      const token = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

      await request(app.getHttpServer())
        .get('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(403);
    });

    it('ACADEMIA_ADMIN cria, lista, detalha e edita valor/diaVencimento', async () => {
      const { academia, token, aluno, plano } = await cenarioBase('Academia CRUD Matricula E2E');

      const criada = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      expect(criada.body.status).toBe('ATIVA');
      expect(criada.body.valor).toBe(150);
      expect(typeof criada.body.valor).toBe('number');
      expect(criada.body.diaVencimento).toBe(10);
      // Projeção de leitura (evita N+1 na Lista de Matrículas — MS3).
      expect(criada.body.alunoNome).toBe(aluno.nome);
      expect(criada.body.planoNome).toBe(plano.nome);
      expect(criada.body.alunoFotoUrl).toBeNull();
      expect(criada.body.dataFimPrevista).toBe(criada.body.dataFim);
      // MENSAL: 10/01 -> 10/02
      expect(new Date(criada.body.dataFim).getUTCMonth()).toBe(1);
      expect(criada.body.createdByUserId).toBeTruthy();

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'MATRICULA_CREATED', academiaId: academia.id },
      });
      expect(auditEntry).not.toBeNull();
      expect(auditEntry?.ipAddress).toBeTruthy();

      const detalhe = await request(app.getHttpServer())
        .get(`/api/matriculas/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(detalhe.body.alunoId).toBe(aluno.id);
      expect(detalhe.body.alunoNome).toBe(aluno.nome);

      const editada = await request(app.getHttpServer())
        .patch(`/api/matriculas/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ valor: 180, diaVencimento: 15 })
        .expect(200);
      expect(editada.body.valor).toBe(180);
      expect(editada.body.diaVencimento).toBe(15);
      expect(editada.body.alunoNome).toBe(aluno.nome);

      const listada = await request(app.getHttpServer())
        .get(`/api/matriculas?alunoId=${aluno.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(listada.body.total).toBe(1);
      expect(listada.body.items[0].alunoNome).toBe(aluno.nome);
      expect(listada.body.items[0].planoNome).toBe(plano.nome);
    });

    it('search filtra por nome do aluno (contains, case-insensitive)', async () => {
      const { token, aluno, plano } = await cenarioBase('Academia Search Matricula E2E');

      await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      const trecho = aluno.nome.slice(0, 5).toUpperCase();
      const encontrada = await request(app.getHttpServer())
        .get(`/api/matriculas?search=${encodeURIComponent(trecho)}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(encontrada.body.total).toBe(1);
      expect(encontrada.body.items[0].alunoNome).toBe(aluno.nome);

      const semResultado = await request(app.getHttpServer())
        .get('/api/matriculas?search=NomeQueNaoExisteNestaAcademia')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(semResultado.body.total).toBe(0);
    });

    it('valor negativo -> 400', async () => {
      const { token, aluno, plano } = await cenarioBase('Academia Valor Invalido Matricula E2E');

      await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10', valor: -10 })
        .expect(400);
    });

    it('aluno inexistente -> 404', async () => {
      const { token, plano } = await cenarioBase('Academia Aluno 404 Matricula E2E');

      await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({
          alunoId: randomUUID(),
          planoId: plano.id,
          dataInicio: '2026-01-10',
        })
        .expect(404);
    });

    it('plano inexistente -> 404', async () => {
      const { token, aluno } = await cenarioBase('Academia Plano 404 Matricula E2E');

      await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({
          alunoId: aluno.id,
          planoId: randomUUID(),
          dataInicio: '2026-01-10',
        })
        .expect(404);
    });

    it('id inexistente -> 404', async () => {
      const { token } = await cenarioBase('Academia 404 Matricula E2E');

      await request(app.getHttpServer())
        .get('/api/matriculas/00000000-0000-0000-0000-000000000099')
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });
  });

  describe('Regra de negócio: 1 matrícula ATIVA por aluno', () => {
    it('criar uma segunda matrícula enquanto a primeira está ATIVA -> 409', async () => {
      const { token, aluno, plano } = await cenarioBase('Academia Uma Ativa Matricula E2E');

      await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      const outroPlano = await createPlanoFixture(
        prisma,
        (await prisma.aluno.findUniqueOrThrow({ where: { id: aluno.id } })).academiaId,
      );

      await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: outroPlano.id, dataInicio: '2026-01-10' })
        .expect(409);
    });

    it('depois de cancelar a primeira, é possível criar uma nova matrícula ativa pro mesmo aluno', async () => {
      const { token, aluno, plano } = await cenarioBase(
        'Academia Nova Apos Cancelar Matricula E2E',
      );

      const primeira = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/matriculas/${primeira.body.id}/cancelar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ motivoCancelamento: 'ALUNO_SOLICITOU' })
        .expect(200);

      await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-02-01' })
        .expect(201);
    });
  });

  describe('Regra oficial: planoId é imutável', () => {
    it('PATCH com planoId no corpo -> 400 (campo não existe no DTO, forbidNonWhitelisted)', async () => {
      const { token, aluno, plano } = await cenarioBase('Academia Plano Imutavel Matricula E2E');
      const outroPlano = await createPlanoFixture(
        prisma,
        (await prisma.aluno.findUniqueOrThrow({ where: { id: aluno.id } })).academiaId,
      );

      const criada = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/matriculas/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ planoId: outroPlano.id })
        .expect(400);

      const aindaOMesmoPlano = await request(app.getHttpServer())
        .get(`/api/matriculas/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(aindaOMesmoPlano.body.planoId).toBe(plano.id);
    });
  });

  describe('Trancamento e reativação', () => {
    it('trancar pausa (status TRANCADA); reativar estende dataFim pelos dias congelados e nunca muda dataFimPrevista', async () => {
      const { token, aluno, plano } = await cenarioBase('Academia Trancamento Matricula E2E');

      const criada = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);
      const dataFimOriginal = criada.body.dataFim;
      const dataFimPrevistaOriginal = criada.body.dataFimPrevista;

      const trancada = await request(app.getHttpServer())
        .patch(`/api/matriculas/${criada.body.id}/trancar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ motivo: 'Viagem' })
        .expect(200);
      expect(trancada.body.status).toBe('TRANCADA');
      expect(trancada.body.trancadoEm).toBeTruthy();
      expect(trancada.body.trancamentoMotivo).toBe('Viagem');

      // Volta pro passado pra simular dias de fato congelados sem precisar
      // esperar de verdade — mesmo princípio de manipular estado direto no
      // banco já usado noutros testes deste projeto quando o tempo importa.
      const tresDiasAtras = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000);
      await prisma.matricula.update({
        where: { id: criada.body.id },
        data: { trancadoEm: tresDiasAtras },
      });

      const reativada = await request(app.getHttpServer())
        .patch(`/api/matriculas/${criada.body.id}/reativar`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(reativada.body.status).toBe('ATIVA');
      expect(reativada.body.trancadoEm).toBeNull();
      expect(reativada.body.trancamentoMotivo).toBeNull();
      expect(new Date(reativada.body.dataFim).getTime()).toBeGreaterThan(
        new Date(dataFimOriginal).getTime(),
      );
      // dataFimPrevista é imutável — nunca é empurrada pelo trancamento.
      expect(reativada.body.dataFimPrevista).toBe(dataFimPrevistaOriginal);
    });

    it('trancar uma matrícula que não está ATIVA -> 400', async () => {
      const { token, aluno, plano } = await cenarioBase('Academia Trancar Invalido Matricula E2E');

      const criada = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/matriculas/${criada.body.id}/trancar`)
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(200);

      // Já está TRANCADA — trancar de novo não é uma transição válida.
      await request(app.getHttpServer())
        .patch(`/api/matriculas/${criada.body.id}/trancar`)
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(400);
    });
  });

  describe('Cancelamento', () => {
    it('motivoCancelamento é obrigatório', async () => {
      const { token, aluno, plano } = await cenarioBase(
        'Academia Cancelar Sem Motivo Matricula E2E',
      );

      const criada = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/matriculas/${criada.body.id}/cancelar`)
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(400);
    });

    it('motivoCancelamento = OUTRO exige motivoCancelamentoDetalhe', async () => {
      const { token, aluno, plano } = await cenarioBase(
        'Academia Cancelar Outro Sem Detalhe Matricula E2E',
      );

      const criada = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/matriculas/${criada.body.id}/cancelar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ motivoCancelamento: 'OUTRO' })
        .expect(400);

      const cancelada = await request(app.getHttpServer())
        .patch(`/api/matriculas/${criada.body.id}/cancelar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ motivoCancelamento: 'OUTRO', motivoCancelamentoDetalhe: 'Mudou de cidade' })
        .expect(200);
      expect(cancelada.body.status).toBe('CANCELADA');
      expect(cancelada.body.motivoCancelamentoDetalhe).toBe('Mudou de cidade');
    });

    it('cancelar com categoria estruturada (sem detalhe) funciona e fica auditado', async () => {
      const { academia, token, aluno, plano } = await cenarioBase(
        'Academia Cancelar Categoria Matricula E2E',
      );

      const criada = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      const cancelada = await request(app.getHttpServer())
        .patch(`/api/matriculas/${criada.body.id}/cancelar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ motivoCancelamento: 'INADIMPLENCIA' })
        .expect(200);
      expect(cancelada.body.status).toBe('CANCELADA');
      expect(cancelada.body.motivoCancelamento).toBe('INADIMPLENCIA');

      const statusAudit = await prisma.auditLog.findFirst({
        where: { action: 'MATRICULA_STATUS_CHANGED', academiaId: academia.id },
        orderBy: { createdAt: 'desc' },
      });
      expect(statusAudit?.metadata).toMatchObject({ motivoCancelamento: 'INADIMPLENCIA' });
    });
  });

  describe('Renovação', () => {
    it('renovar encerra a matrícula atual (ENCERRADA) e cria uma nova ATIVA ligada por matriculaAnteriorId', async () => {
      const { academia, token, aluno, plano } = await cenarioBase('Academia Renovar Matricula E2E');

      const original = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      const renovada = await request(app.getHttpServer())
        .post(`/api/matriculas/${original.body.id}/renovar`)
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(201);

      expect(renovada.body.id).not.toBe(original.body.id);
      expect(renovada.body.status).toBe('ATIVA');
      expect(renovada.body.matriculaAnteriorId).toBe(original.body.id);
      expect(renovada.body.planoId).toBe(plano.id);
      expect(renovada.body.valor).toBe(original.body.valor);
      // dataInicio da renovação = dia seguinte ao dataFim da anterior.
      const diaSeguinte = new Date(original.body.dataFim);
      diaSeguinte.setUTCDate(diaSeguinte.getUTCDate() + 1);
      expect(new Date(renovada.body.dataInicio).toISOString().slice(0, 10)).toBe(
        diaSeguinte.toISOString().slice(0, 10),
      );

      const anteriorAgora = await request(app.getHttpServer())
        .get(`/api/matriculas/${original.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(anteriorAgora.body.status).toBe('ENCERRADA');

      // Renovação também respeita "1 ATIVA por aluno" — só a nova é ATIVA.
      const listaAtivas = await request(app.getHttpServer())
        .get(`/api/matriculas?alunoId=${aluno.id}&status=ATIVA`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(listaAtivas.body.total).toBe(1);
      expect(listaAtivas.body.items[0].id).toBe(renovada.body.id);

      const createdAudit = await prisma.auditLog.findFirst({
        where: { action: 'MATRICULA_CREATED', academiaId: academia.id, userId: { not: null } },
        orderBy: { createdAt: 'desc' },
      });
      expect(createdAudit?.metadata).toMatchObject({ renovacaoDe: original.body.id });
    });

    it('só é possível renovar uma matrícula ATIVA', async () => {
      const { token, aluno, plano } = await cenarioBase('Academia Renovar Invalido Matricula E2E');

      const criada = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/matriculas/${criada.body.id}/cancelar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ motivoCancelamento: 'ALUNO_SOLICITOU' })
        .expect(200);

      await request(app.getHttpServer())
        .post(`/api/matriculas/${criada.body.id}/renovar`)
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(400);
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê, não edita e não cancela matrícula da academia B', async () => {
      const cenarioA = await cenarioBase('Academia Isolamento A Matricula E2E');
      const cenarioB = await cenarioBase('Academia Isolamento B Matricula E2E');

      const matriculaB = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${cenarioB.token}`)
        .send({ alunoId: cenarioB.aluno.id, planoId: cenarioB.plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      await request(app.getHttpServer())
        .get(`/api/matriculas/${matriculaB.body.id}`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(404);

      await request(app.getHttpServer())
        .patch(`/api/matriculas/${matriculaB.body.id}`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({ valor: 1 })
        .expect(404);

      await request(app.getHttpServer())
        .patch(`/api/matriculas/${matriculaB.body.id}/cancelar`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({ motivoCancelamento: 'ALUNO_SOLICITOU' })
        .expect(404);

      const listaA = await request(app.getHttpServer())
        .get('/api/matriculas')
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(200);
      expect(listaA.body.items.some((m: { id: string }) => m.id === matriculaB.body.id)).toBe(
        false,
      );
    });

    it('não é possível criar matrícula usando aluno/plano de outra academia', async () => {
      const cenarioA = await cenarioBase('Academia Isolamento Cross Aluno A Matricula E2E');
      const cenarioB = await cenarioBase('Academia Isolamento Cross Aluno B Matricula E2E');

      await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({ alunoId: cenarioB.aluno.id, planoId: cenarioA.plano.id, dataInicio: '2026-01-10' })
        .expect(404);

      await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({ alunoId: cenarioA.aluno.id, planoId: cenarioB.plano.id, dataInicio: '2026-01-10' })
        .expect(404);
    });
  });

  describe('Soft delete', () => {
    it('DELETE não remove fisicamente — some da listagem mas continua no banco com deletedAt', async () => {
      const { academia, token, aluno, plano } = await cenarioBase(
        'Academia Soft Delete Matricula E2E',
      );

      const criada = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      await request(app.getHttpServer())
        .delete(`/api/matriculas/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(204);

      await request(app.getHttpServer())
        .get(`/api/matriculas/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(404);

      const linhaNoBanco = await prisma.matricula.findUnique({ where: { id: criada.body.id } });
      expect(linhaNoBanco).not.toBeNull();
      expect(linhaNoBanco?.deletedAt).not.toBeNull();

      const deleteAudit = await prisma.auditLog.findFirst({
        where: { action: 'MATRICULA_DELETED', academiaId: academia.id },
      });
      expect(deleteAudit).not.toBeNull();
    });
  });

  /// Sprint de Integridade Financeira (docs/29-auditoria-financeiro-estrutural.md)
  describe('Sprint de Integridade Financeira', () => {
    it('criar matrícula (plano MENSAL) gera automaticamente 1 mensalidade cobrindo a vigência inteira', async () => {
      const { token, aluno, plano } = await cenarioBase('Academia Geracao Automatica Mensal E2E');

      const criada = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      const mensalidades = await request(app.getHttpServer())
        .get(`/api/financeiro/mensalidades?matriculaId=${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(mensalidades.body.total).toBe(1);
      expect(mensalidades.body.items[0]).toMatchObject({
        status: 'PENDENTE',
        valor: criada.body.valor,
      });
      expect(mensalidades.body.items[0].dataVencimento.slice(0, 10)).toBe('2026-01-10');
    });

    it('criar matrícula (plano TRIMESTRAL) gera automaticamente 3 mensalidades, uma por mês da vigência', async () => {
      const { token, aluno, academia } = await cenarioBase(
        'Academia Geracao Automatica Trimestral E2E',
      );
      const planoTrimestral = await request(app.getHttpServer())
        .post('/api/planos')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Trimestral Geração E2E', periodicidade: 'TRIMESTRAL', valor: 300 })
        .expect(201);

      const criada = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: planoTrimestral.body.id, dataInicio: '2026-01-10' })
        .expect(201);

      const mensalidades = await request(app.getHttpServer())
        .get(`/api/financeiro/mensalidades?matriculaId=${criada.body.id}&pageSize=50`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(mensalidades.body.total).toBe(3);
      const vencimentos = mensalidades.body.items
        .map((m: { dataVencimento: string }) => m.dataVencimento.slice(0, 10))
        .sort();
      expect(vencimentos).toEqual(['2026-01-10', '2026-02-10', '2026-03-10']);
      expect(mensalidades.body.items.every((m: { valor: number }) => m.valor === 300)).toBe(true);

      const geradaAudit = await prisma.auditLog.findFirst({
        where: { action: 'MENSALIDADE_GERADA', academiaId: academia.id },
        orderBy: { createdAt: 'desc' },
      });
      expect(geradaAudit?.metadata).toMatchObject({
        matriculaId: criada.body.id,
        origem: 'matricula_criada',
        totalGeradas: 3,
      });
    });

    it('renovação usa periodicidade/valor/diaVencimento da própria matrícula, nunca do Plano atual', async () => {
      const { token, aluno, plano } = await cenarioBase(
        'Academia Renovacao Ignora Plano Atual E2E',
      );

      const original = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);
      expect(original.body.dataFimPrevista.slice(0, 10)).toBe('2026-02-10'); // MENSAL: +1 mês

      // O Plano muda de MENSAL pra ANUAL e o valor sobe — depois da matrícula
      // já criada. Se a renovação lesse o Plano ao vivo, a próxima vigência
      // seria de 12 meses e R$ 999, não 1 mês e o valor original.
      await request(app.getHttpServer())
        .patch(`/api/planos/${plano.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ periodicidade: 'ANUAL', valor: 999 })
        .expect(200);

      const renovada = await request(app.getHttpServer())
        .post(`/api/matriculas/${original.body.id}/renovar`)
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(201);

      expect(renovada.body.valor).toBe(original.body.valor); // 150, não 999
      // dataInicio da renovação = 2026-02-11 (dia seguinte ao dataFim da
      // anterior); dataFimPrevista tem que ser exatamente +1 mês (MENSAL,
      // herdada da matrícula), não +12 meses (ANUAL, do Plano ao vivo).
      expect(renovada.body.dataInicio.slice(0, 10)).toBe('2026-02-11');
      expect(renovada.body.dataFimPrevista.slice(0, 10)).toBe('2026-03-11');

      const novaNoBanco = await prisma.matricula.findUnique({ where: { id: renovada.body.id } });
      expect(novaNoBanco?.periodicidade).toBe('MENSAL');

      // A matrícula original, também no banco, nunca muda por causa da
      // edição do Plano nem da renovação.
      const originalNoBanco = await prisma.matricula.findUnique({
        where: { id: original.body.id },
      });
      expect(originalNoBanco?.periodicidade).toBe('MENSAL');
      expect(Number(originalNoBanco?.valor)).toBe(150);
    });

    it('renovação gera automaticamente as mensalidades da nova vigência', async () => {
      const { token, aluno, plano } = await cenarioBase('Academia Renovacao Gera Mensalidades E2E');

      const original = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      const renovada = await request(app.getHttpServer())
        .post(`/api/matriculas/${original.body.id}/renovar`)
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(201);

      const mensalidadesNovas = await request(app.getHttpServer())
        .get(`/api/financeiro/mensalidades?matriculaId=${renovada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(mensalidadesNovas.body.total).toBe(1);
      // Vencimento cai no diaVencimento (10, herdado da matrícula original),
      // não no dia exato de dataInicio da nova vigência (11) — mesmo
      // critério já usado por `dataVencimentoNoMes` na geração manual.
      expect(mensalidadesNovas.body.items[0].dataVencimento.slice(0, 10)).toBe('2026-02-10');

      // A mensalidade da matrícula original (janeiro) continua existindo,
      // intocada — renovar nunca reaproveita nem sobrescreve.
      const mensalidadesAntigas = await request(app.getHttpServer())
        .get(`/api/financeiro/mensalidades?matriculaId=${original.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(mensalidadesAntigas.body.total).toBe(1);
    });

    it('editar o Plano depois de criar a matrícula não afeta a matrícula existente', async () => {
      const { token, aluno, plano } = await cenarioBase(
        'Academia Edicao Plano Nao Afeta Matricula E2E',
      );

      const criada = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.id, dataInicio: '2026-01-10' })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/planos/${plano.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ valor: 999, periodicidade: 'ANUAL' })
        .expect(200);

      const depoisDaEdicao = await request(app.getHttpServer())
        .get(`/api/matriculas/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(depoisDaEdicao.body.valor).toBe(criada.body.valor);
      expect(depoisDaEdicao.body.diaVencimento).toBe(criada.body.diaVencimento);
      expect(depoisDaEdicao.body.dataFimPrevista).toBe(criada.body.dataFimPrevista);
      expect(depoisDaEdicao.body.status).toBe('ATIVA');

      // Mensalidades já geradas também continuam com o valor antigo.
      const mensalidades = await request(app.getHttpServer())
        .get(`/api/financeiro/mensalidades?matriculaId=${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(mensalidades.body.items[0].valor).toBe(criada.body.valor);
    });
  });
});
