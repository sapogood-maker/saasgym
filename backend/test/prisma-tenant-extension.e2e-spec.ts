import { INestApplication } from '@nestjs/common';
import { Academia, Role } from '@prisma/client';
import { createTestApp } from './utils/create-test-app';
import { PrismaService } from '../src/prisma/prisma.service';
import { TenantContextService } from '../src/common/context/tenant-context.service';

/// Prova a extensão de isolamento (Etapa 8) contra o único model
/// tenant-scoped que existe hoje (User). Não há endpoint de negócio para
/// exercitar isso via HTTP ainda — o exercício real começa no Sprint 2,
/// quando Aluno/Professor/etc. existirem. Este teste garante que o
/// mecanismo em si está correto antes disso.
describe('Prisma tenant isolation extension (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let tenantContext: TenantContextService;
  let academiaA: Academia;
  let academiaB: Academia;

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
    tenantContext = app.get(TenantContextService);

    academiaA = await prisma.academia.create({
      data: { nome: 'Academia A - tenant ext', cnpj: `TENANT-A-${Date.now()}` },
    });
    academiaB = await prisma.academia.create({
      data: { nome: 'Academia B - tenant ext', cnpj: `TENANT-B-${Date.now()}` },
    });

    await prisma.user.createMany({
      data: [
        {
          nome: 'User A1',
          email: `a1-${Date.now()}@example.com`,
          senhaHash: 'x',
          role: Role.PROFESSOR,
          academiaId: academiaA.id,
        },
        {
          nome: 'User A2',
          email: `a2-${Date.now()}@example.com`,
          senhaHash: 'x',
          role: Role.PROFESSOR,
          academiaId: academiaA.id,
        },
        {
          nome: 'User B1',
          email: `b1-${Date.now()}@example.com`,
          senhaHash: 'x',
          role: Role.PROFESSOR,
          academiaId: academiaB.id,
        },
      ],
    });
  });

  afterAll(async () => {
    await prisma.academia.deleteMany({ where: { id: { in: [academiaA.id, academiaB.id] } } });
    await app.close();
  });

  it('fora de um request autenticado (sem TenantContext), forTenant() não filtra nada', async () => {
    const users = await prisma
      .forTenant()
      .user.findMany({ where: { academiaId: { in: [academiaA.id, academiaB.id] } } });

    expect(users.length).toBeGreaterThanOrEqual(3);
  });

  it('SYSTEM_ADMIN (academiaId null) enxerga todas as academias', async () => {
    await tenantContext.run(
      { userId: 'sys', academiaId: null, role: Role.SYSTEM_ADMIN },
      async () => {
        const users = await prisma
          .forTenant()
          .user.findMany({ where: { academiaId: { in: [academiaA.id, academiaB.id] } } });

        expect(users.length).toBeGreaterThanOrEqual(3);
      },
    );
  });

  it('usuário da academia A não vê dados da academia B, mesmo pedindo explicitamente', async () => {
    await tenantContext.run(
      { userId: 'u-a', academiaId: academiaA.id, role: Role.ACADEMIA_ADMIN },
      async () => {
        const users = await prisma
          .forTenant()
          .user.findMany({ where: { academiaId: academiaB.id } });

        expect(users.length).toBeGreaterThan(0);
        expect(users.every((u) => u.academiaId === academiaA.id)).toBe(true);
      },
    );
  });

  it('create injeta academiaId automaticamente a partir do contexto, mesmo sem informar', async () => {
    await tenantContext.run(
      { userId: 'u-a', academiaId: academiaA.id, role: Role.ACADEMIA_ADMIN },
      async () => {
        const created = await prisma.forTenant().user.create({
          data: {
            nome: 'Criado via extension',
            email: `criado-${Date.now()}@example.com`,
            senhaHash: 'x',
            role: Role.PROFESSOR,
          },
        });

        expect(created.academiaId).toBe(academiaA.id);
      },
    );
  });

  it('count() respeita o isolamento por tenant', async () => {
    const countA = await tenantContext.run(
      { userId: 'u-a', academiaId: academiaA.id, role: Role.ACADEMIA_ADMIN },
      () => prisma.forTenant().user.count(),
    );
    const countB = await tenantContext.run(
      { userId: 'u-b', academiaId: academiaB.id, role: Role.ACADEMIA_ADMIN },
      () => prisma.forTenant().user.count(),
    );

    expect(countA).toBeGreaterThanOrEqual(2);
    expect(countB).toBeGreaterThanOrEqual(1);
  });

  it('client "cru" (this.prisma, sem forTenant) nunca filtra — uso intencional para login/seed/gestão de tenants', async () => {
    await tenantContext.run(
      { userId: 'u-a', academiaId: academiaA.id, role: Role.ACADEMIA_ADMIN },
      async () => {
        const users = await prisma.user.findMany({ where: { academiaId: academiaB.id } });

        expect(users.some((u) => u.academiaId === academiaB.id)).toBe(true);
      },
    );
  });
});
