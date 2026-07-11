import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import { createAcademiaFixture } from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

const SENHA = 'SenhaForte123';

describe('Planos (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string): Promise<string> {
    const email = `${role.toLowerCase()}-planos-${Date.now()}-${Math.random()}@example.com`;
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

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('sem token -> 401', async () => {
    await request(app.getHttpServer()).get('/api/planos').expect(401);
  });

  it('SYSTEM_ADMIN (sem academiaId) -> 403 (AcademiaGuard bloqueia)', async () => {
    const senhaHash = await bcrypt.hash(SENHA, 10);
    const email = `sysadmin-planos-${Date.now()}@example.com`;
    await prisma.user.create({
      data: { nome: 'Sys Admin', email, senhaHash, role: Role.SYSTEM_ADMIN },
    });
    const token = (
      await request(app.getHttpServer()).post('/api/auth/login').send({ email, password: SENHA })
    ).body.accessToken;

    await request(app.getHttpServer())
      .get('/api/planos')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  describe('CRUD', () => {
    it('ALUNO (sem permissão nenhuma no módulo) -> 403 ao listar', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Aluno Sem Acesso Plano E2E' });
      const token = await criarUsuarioELogar(Role.ALUNO, academia.id);

      await request(app.getHttpServer())
        .get('/api/planos')
        .set('Authorization', `Bearer ${token}`)
        .expect(403);
    });

    it('PROFESSOR consegue listar mas não criar (403)', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Professor Leitura Plano E2E' });
      const token = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

      await request(app.getHttpServer())
        .get('/api/planos')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      await request(app.getHttpServer())
        .post('/api/planos')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Plano X', periodicidade: 'MENSAL', valor: 100 })
        .expect(403);
    });

    it('ACADEMIA_ADMIN cria, lista, detalha, edita e ativa/inativa um plano', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia CRUD Plano E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      const criado = await request(app.getHttpServer())
        .post('/api/planos')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Plano Mensal Musculação',
          descricao: 'Acesso à musculação',
          periodicidade: 'MENSAL',
          valor: 149.9,
          quantidadeAulas: 12,
        })
        .expect(201);
      expect(criado.body.status).toBe('ATIVO');
      expect(criado.body.valor).toBe(149.9);
      expect(typeof criado.body.valor).toBe('number');

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'PLANO_CREATED', academiaId: academia.id },
      });
      expect(auditEntry).not.toBeNull();
      expect(auditEntry?.ipAddress).toBeTruthy();

      const detalhe = await request(app.getHttpServer())
        .get(`/api/planos/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(detalhe.body.nome).toBe('Plano Mensal Musculação');

      const editado = await request(app.getHttpServer())
        .patch(`/api/planos/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ valor: 159.9 })
        .expect(200);
      expect(editado.body.valor).toBe(159.9);

      const inativado = await request(app.getHttpServer())
        .patch(`/api/planos/${criado.body.id}/status`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'INATIVO', motivo: 'Descontinuado' })
        .expect(200);
      expect(inativado.body.status).toBe('INATIVO');

      const statusAudit = await prisma.auditLog.findFirst({
        where: { action: 'PLANO_STATUS_CHANGED', academiaId: academia.id },
      });
      expect(statusAudit?.metadata).toMatchObject({
        statusNovo: 'INATIVO',
        motivo: 'Descontinuado',
      });
    });

    it('valor negativo -> 400', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Valor Invalido E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .post('/api/planos')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Plano Ruim', periodicidade: 'MENSAL', valor: -10 })
        .expect(400);
    });

    it('periodicidade inválida -> 400', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Periodicidade Invalida E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .post('/api/planos')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Plano Ruim', periodicidade: 'QUINZENAL', valor: 100 })
        .expect(400);
    });

    it('nome duplicado na mesma academia -> 409', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Nome Duplicado Plano E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
      const payload = { nome: 'Plano Repetido', periodicidade: 'MENSAL', valor: 100 };

      await request(app.getHttpServer())
        .post('/api/planos')
        .set('Authorization', `Bearer ${token}`)
        .send(payload)
        .expect(201);

      await request(app.getHttpServer())
        .post('/api/planos')
        .set('Authorization', `Bearer ${token}`)
        .send(payload)
        .expect(409);
    });

    it('mesmo nome em academias diferentes é permitido', async () => {
      const academiaA = await createAcademiaFixture(prisma, { nome: 'Academia Nome Repetido A Plano E2E' });
      const academiaB = await createAcademiaFixture(prisma, { nome: 'Academia Nome Repetido B Plano E2E' });
      const tokenA = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaA.id);
      const tokenB = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaB.id);
      const payload = { nome: 'Plano Padrão', periodicidade: 'MENSAL', valor: 100 };

      await request(app.getHttpServer())
        .post('/api/planos')
        .set('Authorization', `Bearer ${tokenA}`)
        .send(payload)
        .expect(201);

      await request(app.getHttpServer())
        .post('/api/planos')
        .set('Authorization', `Bearer ${tokenB}`)
        .send(payload)
        .expect(201);
    });

    it('id inexistente -> 404', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia 404 Plano E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .get('/api/planos/00000000-0000-0000-0000-000000000099')
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê, não edita e não deleta plano da academia B', async () => {
      const academiaA = await createAcademiaFixture(prisma, { nome: 'Academia Isolamento A Plano E2E' });
      const academiaB = await createAcademiaFixture(prisma, { nome: 'Academia Isolamento B Plano E2E' });
      const tokenA = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaA.id);
      const tokenB = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaB.id);

      const planoB = await request(app.getHttpServer())
        .post('/api/planos')
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ nome: 'Plano da B', periodicidade: 'MENSAL', valor: 100 })
        .expect(201);

      await request(app.getHttpServer())
        .get(`/api/planos/${planoB.body.id}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(404);

      await request(app.getHttpServer())
        .patch(`/api/planos/${planoB.body.id}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ nome: 'Hackeado' })
        .expect(404);

      await request(app.getHttpServer())
        .delete(`/api/planos/${planoB.body.id}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(404);

      const listaA = await request(app.getHttpServer())
        .get('/api/planos')
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(200);
      expect(listaA.body.items.some((p: { id: string }) => p.id === planoB.body.id)).toBe(false);
    });
  });

  describe('Pesquisa e paginação', () => {
    it('pesquisa por nome', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Pesquisa Plano E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .post('/api/planos')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Plano Anual Pesquisável', periodicidade: 'ANUAL', valor: 1200 })
        .expect(201);

      const porNome = await request(app.getHttpServer())
        .get('/api/planos?search=Pesquisável')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(porNome.body.total).toBeGreaterThanOrEqual(1);

      const semResultado = await request(app.getHttpServer())
        .get('/api/planos?search=NomeQueNaoExisteInventadoXYZ')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(semResultado.body.total).toBe(0);
    });

    it('pagina corretamente (pageSize pequeno)', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Paginacao Plano E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      for (const nome of ['Plano Paginado 1', 'Plano Paginado 2']) {
        await request(app.getHttpServer())
          .post('/api/planos')
          .set('Authorization', `Bearer ${token}`)
          .send({ nome, periodicidade: 'MENSAL', valor: 100 })
          .expect(201);
      }

      const pagina1 = await request(app.getHttpServer())
        .get('/api/planos?pageSize=1&page=1')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(pagina1.body.items).toHaveLength(1);
      expect(pagina1.body.total).toBeGreaterThanOrEqual(2);

      const pagina2 = await request(app.getHttpServer())
        .get('/api/planos?pageSize=1&page=2')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(pagina2.body.items).toHaveLength(1);
      expect(pagina2.body.items[0].id).not.toBe(pagina1.body.items[0].id);
    });
  });

  describe('Soft delete', () => {
    it('DELETE não remove fisicamente — some da listagem mas continua no banco com deletedAt', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Soft Delete Plano E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      const criado = await request(app.getHttpServer())
        .post('/api/planos')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Plano Será Removido', periodicidade: 'MENSAL', valor: 100 })
        .expect(201);

      await request(app.getHttpServer())
        .delete(`/api/planos/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(204);

      await request(app.getHttpServer())
        .get(`/api/planos/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(404);

      const linhaNoBanco = await prisma.plano.findUnique({ where: { id: criado.body.id } });
      expect(linhaNoBanco).not.toBeNull();
      expect(linhaNoBanco?.deletedAt).not.toBeNull();

      const deleteAudit = await prisma.auditLog.findFirst({
        where: { action: 'PLANO_DELETED', academiaId: academia.id },
      });
      expect(deleteAudit).not.toBeNull();
    });
  });
});
