import { ConfigService } from '@nestjs/config';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { AcademiaProvisioningService } from './academia-provisioning.service';
import { AuditService } from '../../audit/audit.service';
import { TenantContextService } from '../../../common/context/tenant-context.service';
import { PrismaService } from '../../../prisma/prisma.service';

describe('AcademiaProvisioningService', () => {
  let service: AcademiaProvisioningService;
  let prisma: {
    $transaction: jest.Mock;
    planoSaas: { findFirstOrThrow: jest.Mock };
  };
  let tx: {
    academia: { create: jest.Mock };
    user: { create: jest.Mock };
    academiaConfiguracao: { create: jest.Mock };
  };
  let auditService: { record: jest.Mock };
  let eventEmitter: { emit: jest.Mock };
  let tenantContext: { getUserId: jest.Mock };

  const INPUT = {
    nome: 'Nova Academia',
    adminInicial: { nome: 'Admin', email: 'admin@nova.com', senha: 'SenhaForte123' },
  };

  beforeEach(() => {
    tx = {
      academia: { create: jest.fn().mockResolvedValue({ id: 'academia-1' }) },
      user: { create: jest.fn().mockResolvedValue({ id: 'user-1', email: 'admin@nova.com' }) },
      academiaConfiguracao: { create: jest.fn().mockResolvedValue({}) },
    };
    prisma = {
      $transaction: jest.fn((callback: (tx: unknown) => unknown) => callback(tx)),
      planoSaas: { findFirstOrThrow: jest.fn().mockResolvedValue({ id: 'plano-trial' }) },
    };
    auditService = { record: jest.fn() };
    eventEmitter = { emit: jest.fn() };
    tenantContext = { getUserId: jest.fn().mockReturnValue('system-admin-1') };
    const configService = { get: jest.fn((_key: string, fallback: unknown) => fallback) };

    service = new AcademiaProvisioningService(
      prisma as unknown as PrismaService,
      auditService as unknown as AuditService,
      eventEmitter as unknown as EventEmitter2,
      configService as unknown as ConfigService,
      tenantContext as unknown as TenantContextService,
    );
  });

  it('cria academia + admin inicial + configuração dentro da mesma transação', async () => {
    const result = await service.provision(INPUT);

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(tx.academia.create).toHaveBeenCalled();
    expect(tx.user.create).toHaveBeenCalled();
    expect(tx.academiaConfiguracao.create).toHaveBeenCalledWith({
      data: { academiaId: 'academia-1' },
    });
    expect(result.academia.id).toBe('academia-1');
    expect(result.adminUser.id).toBe('user-1');
  });

  it('sem planoSaasId informado, resolve o plano "Trial" padrão', async () => {
    await service.provision(INPUT);

    expect(prisma.planoSaas.findFirstOrThrow).toHaveBeenCalledWith({ where: { nome: 'Trial' } });
    expect(tx.academia.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ planoSaasId: 'plano-trial' }) }),
    );
  });

  it('com planoSaasId informado, usa o valor direto, sem consultar o plano padrão', async () => {
    await service.provision({ ...INPUT, planoSaasId: 'plano-especifico' });

    expect(prisma.planoSaas.findFirstOrThrow).not.toHaveBeenCalled();
    expect(tx.academia.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ planoSaasId: 'plano-especifico' }),
      }),
    );
  });

  it('nasce com status TRIAL', async () => {
    await service.provision(INPUT);

    expect(tx.academia.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ status: 'TRIAL' }) }),
    );
  });

  it('o primeiro usuário nasce com role ACADEMIA_ADMIN vinculado à academia criada', async () => {
    await service.provision(INPUT);

    expect(tx.user.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        role: 'ACADEMIA_ADMIN',
        academiaId: 'academia-1',
        email: 'admin@nova.com',
      }),
    });
  });

  it('a senha do admin inicial nunca é armazenada em texto puro', async () => {
    await service.provision(INPUT);

    const dataPassada = tx.user.create.mock.calls[0][0].data;
    expect(dataPassada.senhaHash).toBeDefined();
    expect(dataPassada.senhaHash).not.toBe(INPUT.adminInicial.senha);
    expect(dataPassada).not.toHaveProperty('senha');
  });

  it('audita ACADEMIA_CREATED com o autor (SYSTEM_ADMIN do TenantContext), depois do commit', async () => {
    await service.provision(INPUT);

    expect(auditService.record).toHaveBeenCalledWith({
      action: 'ACADEMIA_CREATED',
      academiaId: 'academia-1',
      userId: 'system-admin-1',
      metadata: { adminInicialEmail: 'admin@nova.com' },
    });
  });

  it('emite o evento academia.provisionada depois do commit', async () => {
    await service.provision(INPUT);

    expect(eventEmitter.emit).toHaveBeenCalledWith('academia.provisionada', {
      academiaId: 'academia-1',
      adminUserId: 'user-1',
    });
  });

  it('se a transação falhar, não audita nem emite evento (nada "depois do commit" acontece)', async () => {
    prisma.$transaction.mockRejectedValueOnce(new Error('e-mail do admin já existe'));

    await expect(service.provision(INPUT)).rejects.toThrow('e-mail do admin já existe');
    expect(auditService.record).not.toHaveBeenCalled();
    expect(eventEmitter.emit).not.toHaveBeenCalled();
  });
});
