import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { Academia, AcademiaStatus, AuditAction, Role, User } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { AuditService } from '../../audit/audit.service';
import { RequestMetadata } from '../../../common/utils/request-metadata';
import { TenantContextService } from '../../../common/context/tenant-context.service';
import { PrismaService } from '../../../prisma/prisma.service';

export interface ProvisionAcademiaInput {
  nome: string;
  cnpj?: string;
  email?: string;
  telefone?: string;
  endereco?: string;
  dominio?: string;
  /// Se omitido, usa o plano "Trial" padrão (ver resolveDefaultPlanoId).
  planoSaasId?: string;
  adminInicial: {
    nome: string;
    email: string;
    senha: string;
  };
}

export interface ProvisionAcademiaResult {
  academia: Academia;
  adminUser: User;
}

/// Cria uma academia + seu primeiro usuário ACADEMIA_ADMIN + configuração
/// inicial numa única transação (tudo ou nada — nunca uma academia
/// parcialmente criada). Depois do commit: audita (obrigatório, chamada
/// direta) e emite um evento de domínio (extensão futura — e-mail de
/// boas-vindas etc. — sem nenhum listener hoje, um no-op real).
@Injectable()
export class AcademiaProvisioningService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly eventEmitter: EventEmitter2,
    private readonly configService: ConfigService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async provision(
    input: ProvisionAcademiaInput,
    meta: RequestMetadata = {},
  ): Promise<ProvisionAcademiaResult> {
    const planoSaasId = input.planoSaasId ?? (await this.resolveDefaultPlanoId());
    const senhaHash = await bcrypt.hash(input.adminInicial.senha, 10);
    const trialExpiresAt = this.computeTrialExpiry();

    const { academia, adminUser } = await this.prisma.$transaction(async (tx) => {
      const academia = await tx.academia.create({
        data: {
          nome: input.nome,
          cnpj: input.cnpj,
          email: input.email,
          telefone: input.telefone,
          endereco: input.endereco,
          dominio: input.dominio,
          status: AcademiaStatus.TRIAL,
          trialExpiresAt,
          planoSaasId,
        },
      });

      const adminUser = await tx.user.create({
        data: {
          nome: input.adminInicial.nome,
          email: input.adminInicial.email,
          senhaHash,
          role: Role.ACADEMIA_ADMIN,
          academiaId: academia.id,
        },
      });

      await tx.academiaConfiguracao.create({ data: { academiaId: academia.id } });

      return { academia, adminUser };
    });

    await this.auditService.record({
      action: AuditAction.ACADEMIA_CREATED,
      academiaId: academia.id,
      userId: this.tenantContext.getUserId(),
      metadata: { adminInicialEmail: adminUser.email },
      ...meta,
    });

    this.eventEmitter.emit('academia.provisionada', {
      academiaId: academia.id,
      adminUserId: adminUser.id,
    });

    return { academia, adminUser };
  }

  private async resolveDefaultPlanoId(): Promise<string> {
    const planoTrial = await this.prisma.planoSaas.findFirstOrThrow({ where: { nome: 'Trial' } });
    return planoTrial.id;
  }

  private computeTrialExpiry(): Date {
    const dias = this.configService.get<number>('TRIAL_DURATION_DAYS', 14);
    return new Date(Date.now() + dias * 24 * 60 * 60 * 1000);
  }
}
