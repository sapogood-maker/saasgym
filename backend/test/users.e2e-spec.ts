import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import { createAcademiaFixture } from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  'base64',
);
const SENHA = 'SenhaForte123';

describe('Perfil do usuário (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string | null): Promise<string> {
    const email = `${role.toLowerCase()}-perfil-${Date.now()}-${Math.random()}@example.com`;
    await prisma.user.create({
      data: {
        nome: `Usuário ${role}`,
        email,
        senhaHash: await bcrypt.hash(SENHA, 10),
        role,
        academiaId: academiaId ?? undefined,
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
    await request(app.getHttpServer()).get('/api/users/me').expect(401);
  });

  it('GET/PATCH funcionam para ACADEMIA_ADMIN', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Perfil E2E' });
    const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

    const perfil = await request(app.getHttpServer())
      .get('/api/users/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(perfil.body.role).toBe('ACADEMIA_ADMIN');
    expect(perfil.body.fotoUrl).toBeNull();

    const editado = await request(app.getHttpServer())
      .patch('/api/users/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Nome Atualizado' })
      .expect(200);
    expect(editado.body.nome).toBe('Nome Atualizado');

    const auditEntry = await prisma.auditLog.findFirst({
      where: { action: 'USER_PROFILE_UPDATED' },
    });
    expect(auditEntry).not.toBeNull();
  });

  it('não permite alterar role/permissões (campo nem existe no DTO — extra é rejeitado)', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Perfil Role E2E' });
    const token = await criarUsuarioELogar(Role.RECEPCIONISTA, academia.id);

    await request(app.getHttpServer())
      .patch('/api/users/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Novo Nome', role: 'ACADEMIA_ADMIN' })
      .expect(400);
  });

  it('funciona para SYSTEM_ADMIN também (sem academiaId)', async () => {
    const token = await criarUsuarioELogar(Role.SYSTEM_ADMIN, null);

    const perfil = await request(app.getHttpServer())
      .get('/api/users/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(perfil.body.role).toBe('SYSTEM_ADMIN');
    expect(perfil.body.academiaId).toBeNull();
  });

  it('upload de avatar funciona e serve o arquivo real', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Avatar E2E' });
    const token = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    const res = await request(app.getHttpServer())
      .post('/api/users/me/foto')
      .set('Authorization', `Bearer ${token}`)
      .attach('file', PNG_1X1, 'avatar.png')
      .expect(201);
    expect(res.body.fotoUrl).toMatch(/^\/uploads\/usuarios\/avatares\/.+\.png$/);

    const arquivoRes = await request(app.getHttpServer()).get(res.body.fotoUrl).expect(200);
    expect(Buffer.compare(arquivoRes.body, PNG_1X1)).toBe(0);
  });

  it('senha continua trocando via PATCH /auth/password (não duplicado aqui)', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Senha Perfil E2E' });
    const email = `senha-perfil-${Date.now()}@example.com`;
    await prisma.user.create({
      data: {
        nome: 'Usuário Senha',
        email,
        senhaHash: await bcrypt.hash(SENHA, 10),
        role: Role.ACADEMIA_ADMIN,
        academiaId: academia.id,
      },
    });
    const token = (
      await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email, password: SENHA })
        .expect(200)
    ).body.accessToken;

    await request(app.getHttpServer())
      .patch('/api/auth/password')
      .set('Authorization', `Bearer ${token}`)
      .send({ currentPassword: SENHA, newPassword: 'NovaSenhaForte456' })
      .expect(200);
  });
});
