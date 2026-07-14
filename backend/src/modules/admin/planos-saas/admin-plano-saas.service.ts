import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction, PlanoSaas, Prisma } from '@prisma/client';
import { CreatePlanoSaasDto } from './dto/create-plano-saas.dto';
import { UpdatePlanoSaasDto } from './dto/update-plano-saas.dto';
import { TenantContextService } from '../../../common/context/tenant-context.service';
import { RequestMetadata } from '../../../common/utils/request-metadata';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuditService } from '../../audit/audit.service';

/// Catálogo de planos do SaaS — sem delete (uma academia pode referenciar
/// um plano; apagar a linha quebraria a FK). Desativar via `ativo: false`
/// é a forma de "remover" um plano da oferta sem deixar academias órfãs.
@Injectable()
export class AdminPlanoSaasService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async create(dto: CreatePlanoSaasDto, meta: RequestMetadata = {}): Promise<PlanoSaas> {
    const existente = await this.prisma.planoSaas.findUnique({ where: { nome: dto.nome } });
    if (existente) {
      throw new ConflictException(`Já existe um plano chamado "${dto.nome}"`);
    }

    const plano = await this.prisma.planoSaas.create({
      data: { ...dto, funcionalidades: dto.funcionalidades as Prisma.InputJsonValue | undefined },
    });

    await this.auditService.record({
      action: AuditAction.PLANO_SAAS_CREATED,
      userId: this.tenantContext.getUserId(),
      metadata: { planoSaasId: plano.id, nome: plano.nome },
      ...meta,
    });

    return plano;
  }

  list(): Promise<PlanoSaas[]> {
    return this.prisma.planoSaas.findMany({ orderBy: [{ ordem: 'asc' }, { nome: 'asc' }] });
  }

  async findOne(id: string): Promise<PlanoSaas> {
    const plano = await this.prisma.planoSaas.findUnique({ where: { id } });
    if (!plano) {
      throw new NotFoundException('Plano não encontrado');
    }
    return plano;
  }

  async update(
    id: string,
    dto: UpdatePlanoSaasDto,
    meta: RequestMetadata = {},
  ): Promise<PlanoSaas> {
    await this.findOne(id);

    const plano = await this.prisma.planoSaas.update({
      where: { id },
      data: { ...dto, funcionalidades: dto.funcionalidades as Prisma.InputJsonValue | undefined },
    });

    await this.auditService.record({
      action: AuditAction.PLANO_SAAS_UPDATED,
      userId: this.tenantContext.getUserId(),
      metadata: { planoSaasId: id, camposAlterados: Object.keys(dto) },
      ...meta,
    });

    return plano;
  }
}
