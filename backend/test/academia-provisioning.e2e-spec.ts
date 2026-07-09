import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import { AcademiaProvisioningService } from '../src/modules/admin/academias/academia-provisioning.service';
import { AuthService } from '../src/modules/auth/auth.service';
import { TenantContextService } from '../src/common/context/tenant-context.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { createTestApp } from './utils/create-test-app';

/// Prova, contra Postgres real, que a criação de academia é
/// verdadeiramente transacional (rollback completo em falha) e que a
/// academia nasce imediatamente utilizável (o admin criado já consegue
/// logar sem nenhum passo manual).
describe('AcademiaProvisioningService (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let service: AcademiaProvisioningService;
  let authService: AuthService;
  let tenantContext: TenantContextService;

  const asSystemAdmin = <T>(fn: () => Promise<T>): Promise<T> =>
    tenantContext.run(
      { userId: 'system-admin-e2e', academiaId: null, role: Role.SYSTEM_ADMIN },
      fn,
    );

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
    service = app.get(AcademiaProvisioningService);
    authService = app.get(AuthService);
    tenantContext = app.get(TenantContextService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('cria academia + admin + configuração numa única operação, e o admin já consegue logar', async () => {
    const email = `admin-provisionado-${Date.now()}@example.com`;

    const { academia, adminUser } = await asSystemAdmin(() =>
      service.provision({
        nome: 'Academia Provisionada E2E',
        cnpj: `PROV-${Date.now()}`,
        adminInicial: { nome: 'Admin Provisionado', email, senha: 'SenhaForte123' },
      }),
    );

    expect(academia.status).toBe('TRIAL');
    expect(academia.trialExpiresAt).not.toBeNull();
    expect(adminUser.role).toBe('ACADEMIA_ADMIN');

    const configuracao = await prisma.academiaConfiguracao.findUnique({
      where: { academiaId: academia.id },
    });
    expect(configuracao).not.toBeNull();

    const loginResult = await authService.login(email, 'SenhaForte123', {});
    expect(loginResult.accessToken).toBeDefined();
    expect(loginResult.user.academiaId).toBe(academia.id);

    await prisma.academia.delete({ where: { id: academia.id } });
  });

  it('registra auditoria ACADEMIA_CREATED com o academiaId correto', async () => {
    const email = `admin-audit-${Date.now()}@example.com`;

    const { academia } = await asSystemAdmin(() =>
      service.provision({
        nome: 'Academia Auditoria E2E',
        cnpj: `AUDIT-${Date.now()}`,
        adminInicial: { nome: 'Admin', email, senha: 'SenhaForte123' },
      }),
    );

    const auditEntry = await prisma.auditLog.findFirst({
      where: { action: 'ACADEMIA_CREATED', academiaId: academia.id },
    });
    expect(auditEntry).not.toBeNull();
    expect(auditEntry?.userId).toBe('system-admin-e2e');

    await prisma.academia.delete({ where: { id: academia.id } });
  });

  it('rollback real: e-mail do admin duplicado não deixa academia parcialmente criada', async () => {
    const email = `admin-duplicado-${Date.now()}@example.com`;

    const { academia: primeira } = await asSystemAdmin(() =>
      service.provision({
        nome: 'Academia Original E2E',
        cnpj: `ORIG-${Date.now()}`,
        adminInicial: { nome: 'Admin', email, senha: 'SenhaForte123' },
      }),
    );

    await expect(
      asSystemAdmin(() =>
        service.provision({
          nome: 'Academia Que Não Deveria Existir',
          cnpj: `DUP-${Date.now()}`,
          adminInicial: { nome: 'Admin Duplicado', email, senha: 'OutraSenha123' },
        }),
      ),
    ).rejects.toThrow();

    const academiaFalha = await prisma.academia.findFirst({
      where: { nome: 'Academia Que Não Deveria Existir' },
    });
    expect(academiaFalha).toBeNull();

    const configuracaoOrfa = await prisma.academiaConfiguracao.findMany({
      where: { academia: { nome: 'Academia Que Não Deveria Existir' } },
    });
    expect(configuracaoOrfa).toHaveLength(0);

    await prisma.academia.delete({ where: { id: primeira.id } });
  });
});
