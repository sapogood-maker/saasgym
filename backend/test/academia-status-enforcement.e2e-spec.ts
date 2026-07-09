import { INestApplication } from '@nestjs/common';
import { AcademiaStatus, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import { createAcademiaFixture } from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

/// Prova que login/refresh respeitam o status da academia — não só a
/// revogação em cascata (Etapa 5), mas o bloqueio de uma tentativa NOVA de
/// login/refresh enquanto a academia está suspensa/bloqueada/cancelada.
describe('Aplicação do status da academia (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  const SENHA = 'SenhaForte123';

  async function criarUsuarioNaAcademia(status: AcademiaStatus) {
    const academia = await createAcademiaFixture(prisma, {
      nome: `Academia Status ${status} ${Date.now()}`,
      status,
    });
    const email = `usuario-${status.toLowerCase()}-${Date.now()}@example.com`;
    await prisma.user.create({
      data: {
        nome: `Usuário ${status}`,
        email,
        senhaHash: await bcrypt.hash(SENHA, 10),
        role: Role.ACADEMIA_ADMIN,
        academiaId: academia.id,
      },
    });
    return { academia, email };
  }

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  describe.each([AcademiaStatus.SUSPENSA, AcademiaStatus.BLOQUEADA, AcademiaStatus.CANCELADA])(
    'academia com status %s',
    (status) => {
      it('bloqueia login mesmo com credenciais corretas', async () => {
        const { email } = await criarUsuarioNaAcademia(status);

        const res = await request(app.getHttpServer())
          .post('/api/auth/login')
          .send({ email, password: SENHA })
          .expect(401);

        expect(res.body.message).toMatch(/suspenso/i);
      });

      it('audita LOGIN_FAILURE com o motivo do bloqueio', async () => {
        const { email, academia } = await criarUsuarioNaAcademia(status);

        await request(app.getHttpServer())
          .post('/api/auth/login')
          .send({ email, password: SENHA })
          .expect(401);

        const auditEntry = await prisma.auditLog.findFirst({
          where: { action: 'LOGIN_FAILURE', academiaId: academia.id },
        });
        expect(auditEntry?.metadata).toMatchObject({
          motivo: 'academia_status_bloqueante',
          status,
        });
      });

      it('bloqueia refresh de uma sessão cuja academia ficou bloqueada depois do login', async () => {
        const { email, academia } = await criarUsuarioNaAcademia(AcademiaStatus.ATIVA);
        await prisma.academia.update({ where: { id: academia.id }, data: { status: 'ATIVA' } });

        const loginRes = await request(app.getHttpServer())
          .post('/api/auth/login')
          .send({ email, password: SENHA })
          .expect(200);
        const refreshCookie = (loginRes.headers['set-cookie'] as unknown as string[])
          .find((c) => c.startsWith('refreshToken='))!
          .split(';')[0];

        // muda o status direto no banco (sem passar pelo endpoint admin,
        // que já revoga em cascata) para isolar exatamente a checagem do
        // AuthService.refresh, não a cascata da Etapa 5.
        await prisma.academia.update({ where: { id: academia.id }, data: { status } });

        await request(app.getHttpServer())
          .post('/api/auth/refresh')
          .set('Cookie', refreshCookie)
          .expect(401);
      });
    },
  );

  describe.each([AcademiaStatus.TRIAL, AcademiaStatus.ATIVA])(
    'academia com status %s',
    (status) => {
      it('permite login normalmente', async () => {
        const { email } = await criarUsuarioNaAcademia(status);

        await request(app.getHttpServer())
          .post('/api/auth/login')
          .send({ email, password: SENHA })
          .expect(200);
      });
    },
  );
});
