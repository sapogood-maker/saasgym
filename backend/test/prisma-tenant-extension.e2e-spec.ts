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

  it('findUnique por id não vaza registro de outra academia (nem quebra o Prisma)', async () => {
    const userB = await prisma.user.findFirstOrThrow({ where: { academiaId: academiaB.id } });

    await tenantContext.run(
      { userId: 'u-a', academiaId: academiaA.id, role: Role.ACADEMIA_ADMIN },
      async () => {
        const found = await prisma.forTenant().user.findUnique({ where: { id: userB.id } });
        expect(found).toBeNull();
      },
    );
  });

  it('update por id só afeta registro da própria academia', async () => {
    const userA = await prisma.user.findFirstOrThrow({ where: { academiaId: academiaA.id } });
    const userB = await prisma.user.findFirstOrThrow({ where: { academiaId: academiaB.id } });

    await tenantContext.run(
      { userId: 'u-a', academiaId: academiaA.id, role: Role.ACADEMIA_ADMIN },
      async () => {
        const updated = await prisma
          .forTenant()
          .user.update({ where: { id: userA.id }, data: { nome: 'Atualizado via extension' } });
        expect(updated.nome).toBe('Atualizado via extension');

        await expect(
          prisma.forTenant().user.update({ where: { id: userB.id }, data: { nome: 'Hackeado' } }),
        ).rejects.toThrow();
      },
    );

    const userBAfter = await prisma.user.findUniqueOrThrow({ where: { id: userB.id } });
    expect(userBAfter.nome).not.toBe('Hackeado');
  });

  it('delete por id só afeta registro da própria academia', async () => {
    const toDelete = await prisma.user.create({
      data: {
        nome: 'Vai ser deletado',
        email: `delete-alvo-${Date.now()}@example.com`,
        senhaHash: 'x',
        role: Role.PROFESSOR,
        academiaId: academiaB.id,
      },
    });

    await tenantContext.run(
      { userId: 'u-a', academiaId: academiaA.id, role: Role.ACADEMIA_ADMIN },
      async () => {
        await expect(
          prisma.forTenant().user.delete({ where: { id: toDelete.id } }),
        ).rejects.toThrow();
      },
    );

    const stillExists = await prisma.user.findUnique({ where: { id: toDelete.id } });
    expect(stillExists).not.toBeNull();
  });

  it('upsert respeita o isolamento (branch update E branch create)', async () => {
    const userA = await prisma.user.findFirstOrThrow({ where: { academiaId: academiaA.id } });
    const userB = await prisma.user.findFirstOrThrow({ where: { academiaId: academiaB.id } });

    await tenantContext.run(
      { userId: 'u-a', academiaId: academiaA.id, role: Role.ACADEMIA_ADMIN },
      async () => {
        // branch update: registro é da própria academia -> deve atualizar
        const updated = await prisma.forTenant().user.upsert({
          where: { id: userA.id },
          update: { nome: 'Atualizado via upsert' },
          create: {
            nome: 'Não deveria criar',
            email: `nao-deveria-${Date.now()}@example.com`,
            senhaHash: 'x',
            role: Role.PROFESSOR,
          },
        });
        expect(updated.id).toBe(userA.id);
        expect(updated.nome).toBe('Atualizado via upsert');

        // branch update: registro é de OUTRA academia -> não pode achar por
        // esse id sob o filtro, então cai no branch create (comportamento
        // esperado do Prisma) — e o create precisa injetar academiaId.
        const result = await prisma.forTenant().user.upsert({
          where: { id: userB.id },
          update: { nome: 'Não deveria tocar em B' },
          create: {
            nome: 'Criado via upsert (fallback)',
            email: `upsert-fallback-${Date.now()}@example.com`,
            senhaHash: 'x',
            role: Role.PROFESSOR,
          },
        });
        expect(result.academiaId).toBe(academiaA.id);
      },
    );

    const userBAfter = await prisma.user.findUniqueOrThrow({ where: { id: userB.id } });
    expect(userBAfter.nome).not.toBe('Não deveria tocar em B');
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
