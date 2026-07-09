import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import { createAcademiaFixture } from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Admin Planos SaaS (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let systemAdminToken: string;
  let academiaAdminToken: string;

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);

    const senha = 'SenhaForte123';
    const senhaHash = await bcrypt.hash(senha, 10);

    const sysAdminEmail = `sysadmin-planos-${Date.now()}@example.com`;
    await prisma.user.create({
      data: {
        nome: 'Sys Admin Planos E2E',
        email: sysAdminEmail,
        senhaHash,
        role: Role.SYSTEM_ADMIN,
      },
    });
    systemAdminToken = (
      await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: sysAdminEmail, password: senha })
        .expect(200)
    ).body.accessToken;

    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Planos E2E' });
    const academiaAdminEmail = `academiaadmin-planos-${Date.now()}@example.com`;
    await prisma.user.create({
      data: {
        nome: 'Academia Admin Planos E2E',
        email: academiaAdminEmail,
        senhaHash,
        role: Role.ACADEMIA_ADMIN,
        academiaId: academia.id,
      },
    });
    academiaAdminToken = (
      await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: academiaAdminEmail, password: senha })
        .expect(200)
    ).body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  it('sem token -> 401', async () => {
    await request(app.getHttpServer()).get('/api/admin/planos-saas').expect(401);
  });

  it('com token de ACADEMIA_ADMIN -> 403', async () => {
    await request(app.getHttpServer())
      .get('/api/admin/planos-saas')
      .set('Authorization', `Bearer ${academiaAdminToken}`)
      .expect(403);
  });

  it('cria um plano', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/admin/planos-saas')
      .set('Authorization', `Bearer ${systemAdminToken}`)
      .send({ nome: `Plano Teste ${Date.now()}`, limiteAlunos: 100, limiteProfessores: 5 })
      .expect(201);

    expect(res.body.ativo).toBe(true);
    expect(res.body.limiteAlunos).toBe(100);

    const auditEntry = await prisma.auditLog.findFirst({ where: { action: 'PLANO_SAAS_CREATED' } });
    expect(auditEntry).not.toBeNull();
  });

  it('rejeita nome duplicado -> 409', async () => {
    const nome = `Plano Duplicado ${Date.now()}`;
    await request(app.getHttpServer())
      .post('/api/admin/planos-saas')
      .set('Authorization', `Bearer ${systemAdminToken}`)
      .send({ nome })
      .expect(201);

    await request(app.getHttpServer())
      .post('/api/admin/planos-saas')
      .set('Authorization', `Bearer ${systemAdminToken}`)
      .send({ nome })
      .expect(409);
  });

  it('lista os planos (inclui os seeds Free/Trial/Basic/Professional/Enterprise)', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/admin/planos-saas')
      .set('Authorization', `Bearer ${systemAdminToken}`)
      .expect(200);

    expect(res.body.some((p: { nome: string }) => p.nome === 'Trial')).toBe(true);
  });

  it('edita um plano (limites e ordem)', async () => {
    const criado = await request(app.getHttpServer())
      .post('/api/admin/planos-saas')
      .set('Authorization', `Bearer ${systemAdminToken}`)
      .send({ nome: `Plano Editar ${Date.now()}`, limiteAlunos: 10 })
      .expect(201);

    const editado = await request(app.getHttpServer())
      .patch(`/api/admin/planos-saas/${criado.body.id}`)
      .set('Authorization', `Bearer ${systemAdminToken}`)
      .send({ limiteAlunos: 999 })
      .expect(200);

    expect(editado.body.limiteAlunos).toBe(999);

    const auditEntry = await prisma.auditLog.findFirst({
      where: {
        action: 'PLANO_SAAS_UPDATED',
        metadata: { path: ['planoSaasId'], equals: criado.body.id },
      },
    });
    expect(auditEntry).not.toBeNull();
  });

  it('"remove" um plano via ativo:false (não há delete)', async () => {
    const criado = await request(app.getHttpServer())
      .post('/api/admin/planos-saas')
      .set('Authorization', `Bearer ${systemAdminToken}`)
      .send({ nome: `Plano Desativar ${Date.now()}` })
      .expect(201);

    const desativado = await request(app.getHttpServer())
      .patch(`/api/admin/planos-saas/${criado.body.id}`)
      .set('Authorization', `Bearer ${systemAdminToken}`)
      .send({ ativo: false })
      .expect(200);

    expect(desativado.body.ativo).toBe(false);
  });

  it('id inexistente -> 404', async () => {
    await request(app.getHttpServer())
      .get('/api/admin/planos-saas/00000000-0000-0000-0000-000000000099')
      .set('Authorization', `Bearer ${systemAdminToken}`)
      .expect(404);
  });
});
