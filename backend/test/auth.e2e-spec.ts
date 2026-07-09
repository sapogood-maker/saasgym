import { INestApplication } from '@nestjs/common';
import { Academia, AuditAction, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import { createAcademiaFixture } from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

function extractRefreshCookie(response: request.Response): string {
  const cookie = (response.headers['set-cookie'] as unknown as string[])?.find((c) =>
    c.startsWith('refreshToken='),
  );
  if (!cookie) throw new Error('cookie refreshToken não encontrado na resposta');
  return cookie.split(';')[0];
}

describe('Auth (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let testAcademia: Academia;

  const TEST_EMAIL = 'e2e-auth@example.com';
  const TEST_PASSWORD = 'SenhaForte123';

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);

    testAcademia = await createAcademiaFixture(prisma, {
      nome: 'Academia E2E Auth',
      cnpj: `E2E-${Date.now()}`,
    });

    await prisma.user.create({
      data: {
        nome: 'Usuário E2E',
        email: TEST_EMAIL,
        senhaHash: await bcrypt.hash(TEST_PASSWORD, 10),
        role: Role.ACADEMIA_ADMIN,
        academiaId: testAcademia.id,
      },
    });
  });

  afterAll(async () => {
    // onDelete: Cascade em User->RefreshToken e Academia->User cuida do resto.
    await prisma.academia.deleteMany({ where: { id: testAcademia.id } });
    await app.close();
  });

  describe('POST /api/auth/login', () => {
    it('credenciais corretas -> 200, accessToken, usuário e cookie de refresh', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: TEST_PASSWORD })
        .expect(200);

      expect(response.body.accessToken).toEqual(expect.any(String));
      expect(response.body.user).toMatchObject({
        email: TEST_EMAIL,
        role: Role.ACADEMIA_ADMIN,
        academiaId: testAcademia.id,
      });
      expect(response.headers['set-cookie']?.[0]).toMatch(/refreshToken=/);
    });

    it('senha errada -> 401', async () => {
      await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: 'senhaErrada123' })
        .expect(401);
    });

    it('e-mail inexistente -> 401 (mesma mensagem genérica, sem indicar qual campo errou)', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: 'nao-existe@example.com', password: 'qualquercoisa' })
        .expect(401);

      const wrongPasswordResponse = await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: 'senhaErrada123' })
        .expect(401);

      expect(response.body.message).toBe(wrongPasswordResponse.body.message);
    });

    it('corpo inválido (e-mail malformado) -> 400', async () => {
      await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: 'nao-e-email', password: 'x' })
        .expect(400);
    });

    it('registra auditoria de login bem-sucedido e falho', async () => {
      await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: TEST_PASSWORD })
        .expect(200);

      await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: 'errada-de-novo' })
        .expect(401);

      const logs = await prisma.auditLog.findMany({
        where: { identifier: TEST_EMAIL },
        orderBy: { createdAt: 'desc' },
        take: 5,
      });

      const actions = logs.map((log) => log.action);
      expect(actions).toEqual(
        expect.arrayContaining([AuditAction.LOGIN_SUCCESS, AuditAction.LOGIN_FAILURE]),
      );
    });
  });

  describe('GET /api/auth/me', () => {
    it('sem token -> 401', async () => {
      await request(app.getHttpServer()).get('/api/auth/me').expect(401);
    });

    it('token com assinatura inválida -> 401', async () => {
      await request(app.getHttpServer())
        .get('/api/auth/me')
        .set('Authorization', 'Bearer token.invalido.aqui')
        .expect(401);
    });

    it('com token válido -> 200, dados do usuário autenticado', async () => {
      const loginResponse = await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: TEST_PASSWORD })
        .expect(200);

      const { accessToken } = loginResponse.body;

      const meResponse = await request(app.getHttpServer())
        .get('/api/auth/me')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(meResponse.body).toMatchObject({
        email: TEST_EMAIL,
        academiaId: testAcademia.id,
        role: Role.ACADEMIA_ADMIN,
      });
    });
  });

  describe('POST /api/auth/refresh', () => {
    it('sem cookie -> 401', async () => {
      await request(app.getHttpServer()).post('/api/auth/refresh').expect(401);
    });

    it('cookie com valor inválido -> 401', async () => {
      await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .set('Cookie', 'refreshToken=nao-existe-no-banco')
        .expect(401);
    });

    it('cookie válido -> 200, novo accessToken e novo cookie (rotação)', async () => {
      const loginResponse = await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: TEST_PASSWORD })
        .expect(200);
      const originalCookie = extractRefreshCookie(loginResponse);

      const refreshResponse = await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .set('Cookie', originalCookie)
        .expect(200);

      // Não comparamos accessToken novo vs. antigo: se emitidos no mesmo
      // segundo, o JWT (mesmo payload + mesmo "iat") sai byte-idêntico —
      // isso não é uma falha de segurança, só uma coincidência de timing.
      // A garantia real de rotação é o refresh token (abaixo) ser diferente.
      expect(refreshResponse.body.accessToken).toEqual(expect.any(String));

      const newCookie = extractRefreshCookie(refreshResponse);
      expect(newCookie).not.toBe(originalCookie);
    });

    it('o token antigo não funciona mais depois de rotacionado', async () => {
      const loginResponse = await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: TEST_PASSWORD })
        .expect(200);
      const originalCookie = extractRefreshCookie(loginResponse);

      await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .set('Cookie', originalCookie)
        .expect(200);

      // reapresentando o cookie ORIGINAL (já rotacionado) -> deve falhar
      await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .set('Cookie', originalCookie)
        .expect(401);
    });

    it('reuso de token revogado derruba TODAS as sessões do usuário (não só a reaproveitada)', async () => {
      // duas sessões (dois "dispositivos") para o mesmo usuário
      const sessionA = await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: TEST_PASSWORD })
        .expect(200);
      const cookieA = extractRefreshCookie(sessionA);

      const sessionB = await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: TEST_PASSWORD })
        .expect(200);
      const cookieB = extractRefreshCookie(sessionB);

      // rotaciona A normalmente, depois reapresenta o cookie A original -> reuso detectado
      await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .set('Cookie', cookieA)
        .expect(200);
      await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .set('Cookie', cookieA)
        .expect(401);

      // a sessão B, que nunca foi reaproveitada, também deve estar revogada agora
      await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .set('Cookie', cookieB)
        .expect(401);

      const reuseLog = await prisma.auditLog.findFirst({
        where: { action: AuditAction.REFRESH_TOKEN_REUSE_DETECTED },
        orderBy: { createdAt: 'desc' },
      });
      expect(reuseLog).not.toBeNull();
    });
  });

  describe('POST /api/auth/logout', () => {
    it('sem access token -> 401', async () => {
      await request(app.getHttpServer()).post('/api/auth/logout').expect(401);
    });

    it('revoga o refresh token atual (refresh depois de logout -> 401) e limpa o cookie', async () => {
      const loginResponse = await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: TEST_PASSWORD })
        .expect(200);
      const { accessToken } = loginResponse.body;
      const refreshCookie = extractRefreshCookie(loginResponse);

      const logoutResponse = await request(app.getHttpServer())
        .post('/api/auth/logout')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('Cookie', refreshCookie)
        .expect(200);

      expect(logoutResponse.headers['set-cookie']?.[0]).toMatch(/refreshToken=;/);

      await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .set('Cookie', refreshCookie)
        .expect(401);
    });

    it('é idempotente — chamar duas vezes não é erro', async () => {
      const loginResponse = await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: TEST_PASSWORD })
        .expect(200);
      const { accessToken } = loginResponse.body;
      const refreshCookie = extractRefreshCookie(loginResponse);

      await request(app.getHttpServer())
        .post('/api/auth/logout')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('Cookie', refreshCookie)
        .expect(200);

      await request(app.getHttpServer())
        .post('/api/auth/logout')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('Cookie', refreshCookie)
        .expect(200);
    });
  });

  describe('PATCH /api/auth/password', () => {
    // Usuário dedicado — trocar a senha não pode contaminar os outros testes.
    const PASSWORD_TEST_EMAIL = 'e2e-password@example.com';
    const ORIGINAL_PASSWORD = 'SenhaOriginal123';
    let passwordTestUserId: string;

    beforeAll(async () => {
      const user = await prisma.user.create({
        data: {
          nome: 'Usuário Troca de Senha',
          email: PASSWORD_TEST_EMAIL,
          senhaHash: await bcrypt.hash(ORIGINAL_PASSWORD, 10),
          role: Role.PROFESSOR,
          academiaId: testAcademia.id,
        },
      });
      passwordTestUserId = user.id;
    });

    it('sem autenticação -> 401', async () => {
      await request(app.getHttpServer())
        .patch('/api/auth/password')
        .send({ currentPassword: 'x', newPassword: 'NovaSenh4Forte' })
        .expect(401);
    });

    it('senha nova fora da política mínima -> 400', async () => {
      const loginResponse = await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: PASSWORD_TEST_EMAIL, password: ORIGINAL_PASSWORD })
        .expect(200);

      await request(app.getHttpServer())
        .patch('/api/auth/password')
        .set('Authorization', `Bearer ${loginResponse.body.accessToken}`)
        .send({ currentPassword: ORIGINAL_PASSWORD, newPassword: 'fraca' })
        .expect(400);
    });

    it('senha atual incorreta -> 401', async () => {
      const loginResponse = await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: PASSWORD_TEST_EMAIL, password: ORIGINAL_PASSWORD })
        .expect(200);

      await request(app.getHttpServer())
        .patch('/api/auth/password')
        .set('Authorization', `Bearer ${loginResponse.body.accessToken}`)
        .send({ currentPassword: 'senhaErradaQualquer', newPassword: 'NovaSenh4Forte' })
        .expect(401);
    });

    it('sucesso: muda a senha, revoga a sessão atual, senha antiga para de funcionar', async () => {
      const NEW_PASSWORD = 'NovaSenh4Forte';
      const loginResponse = await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: PASSWORD_TEST_EMAIL, password: ORIGINAL_PASSWORD })
        .expect(200);
      const { accessToken } = loginResponse.body;
      const refreshCookie = extractRefreshCookie(loginResponse);

      await request(app.getHttpServer())
        .patch('/api/auth/password')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ currentPassword: ORIGINAL_PASSWORD, newPassword: NEW_PASSWORD })
        .expect(200);

      // a sessão que trocou a senha também foi revogada
      await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .set('Cookie', refreshCookie)
        .expect(401);

      // senha antiga não funciona mais
      await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: PASSWORD_TEST_EMAIL, password: ORIGINAL_PASSWORD })
        .expect(401);

      // senha nova funciona
      await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: PASSWORD_TEST_EMAIL, password: NEW_PASSWORD })
        .expect(200);

      const log = await prisma.auditLog.findFirst({
        where: { action: AuditAction.PASSWORD_CHANGED, userId: passwordTestUserId },
      });
      expect(log).not.toBeNull();
    });
  });
});
