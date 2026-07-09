import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import { createAcademiaFixture } from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Admin Dashboard (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let systemAdminToken: string;
  let academiaAdminToken: string;

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);

    const senha = 'SenhaForte123';
    const senhaHash = await bcrypt.hash(senha, 10);

    const sysAdminEmail = `sysadmin-dash-${Date.now()}@example.com`;
    await prisma.user.create({
      data: {
        nome: 'Sys Admin Dash E2E',
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

    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Dashboard E2E' });
    const academiaAdminEmail = `academiaadmin-dash-${Date.now()}@example.com`;
    await prisma.user.create({
      data: {
        nome: 'Academia Admin Dash E2E',
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
    await request(app.getHttpServer()).get('/api/admin/dashboard').expect(401);
  });

  it('com token de ACADEMIA_ADMIN -> 403', async () => {
    await request(app.getHttpServer())
      .get('/api/admin/dashboard')
      .set('Authorization', `Bearer ${academiaAdminToken}`)
      .expect(403);
  });

  it('retorna agregados reais', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/admin/dashboard')
      .set('Authorization', `Bearer ${systemAdminToken}`)
      .expect(200);

    expect(res.body.totalAcademias).toBeGreaterThanOrEqual(1);
    expect(typeof res.body.academiasPorStatus.TRIAL).toBe('number');
    expect(typeof res.body.armazenamentoUsadoBytes).toBe('number');
    expect(res.body.backups).toEqual({ disponivel: false, quantidade: 0 });
    expect(typeof res.body.versaoInstalada).toBe('string');
  });

  it('reflete mudanças reais na contagem por status', async () => {
    const antes = await request(app.getHttpServer())
      .get('/api/admin/dashboard')
      .set('Authorization', `Bearer ${systemAdminToken}`)
      .expect(200);

    await createAcademiaFixture(prisma, {
      nome: 'Academia Cancelada Dashboard E2E',
      status: 'CANCELADA',
    });

    const depois = await request(app.getHttpServer())
      .get('/api/admin/dashboard')
      .set('Authorization', `Bearer ${systemAdminToken}`)
      .expect(200);

    expect(depois.body.academiasPorStatus.CANCELADA).toBe(
      antes.body.academiasPorStatus.CANCELADA + 1,
    );
    expect(depois.body.totalAcademias).toBe(antes.body.totalAcademias + 1);
  });
});
