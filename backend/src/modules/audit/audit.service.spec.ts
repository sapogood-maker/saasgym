import { Test } from '@nestjs/testing';
import { AuditAction } from '@prisma/client';
import { AuditService } from './audit.service';
import { PrismaService } from '../../prisma/prisma.service';

describe('AuditService', () => {
  let service: AuditService;
  let prisma: { auditLog: { create: jest.Mock } };

  beforeEach(async () => {
    prisma = { auditLog: { create: jest.fn() } };

    const module = await Test.createTestingModule({
      providers: [AuditService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = module.get(AuditService);
  });

  it('grava o evento com os dados informados', async () => {
    prisma.auditLog.create.mockResolvedValue({});

    await service.record({
      action: AuditAction.LOGIN_SUCCESS,
      userId: 'user-1',
      academiaId: 'academia-1',
      ipAddress: '127.0.0.1',
      userAgent: 'jest',
    });

    expect(prisma.auditLog.create).toHaveBeenCalledWith({
      data: {
        action: AuditAction.LOGIN_SUCCESS,
        userId: 'user-1',
        academiaId: 'academia-1',
        ipAddress: '127.0.0.1',
        userAgent: 'jest',
      },
    });
  });

  it('nunca propaga erro de escrita (auditoria não pode derrubar login/logout/etc.)', async () => {
    prisma.auditLog.create.mockRejectedValue(new Error('db indisponível'));

    await expect(
      service.record({ action: AuditAction.LOGIN_FAILURE, identifier: 'teste@example.com' }),
    ).resolves.toBeUndefined();
  });
});
