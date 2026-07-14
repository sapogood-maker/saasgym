import { Injectable, NotFoundException } from '@nestjs/common';
import { Academia, AuditAction } from '@prisma/client';
import {
  AcademiaProvisioningService,
  ProvisionAcademiaInput,
} from './academia-provisioning.service';
import { ListAcademiasQueryDto } from './dto/list-academias-query.dto';
import { UpdateAcademiaDto } from './dto/update-academia.dto';
import { UpdateAcademiaStatusDto } from './dto/update-academia-status.dto';
import { isAcademiaStatusBlocking } from '../../../common/academia/academia-status.util';
import { TenantContextService } from '../../../common/context/tenant-context.service';
import { RequestMetadata } from '../../../common/utils/request-metadata';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuditService } from '../../audit/audit.service';

export interface PaginatedAcademias {
  items: Academia[];
  total: number;
  page: number;
  pageSize: number;
}

/// CRUD simples de academia — a criação (com todas as suas implicações
/// transacionais) fica em AcademiaProvisioningService; este service só
/// orquestra o caso de uso HTTP em cima dele.
@Injectable()
export class AdminAcademiaService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly provisioningService: AcademiaProvisioningService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async create(input: ProvisionAcademiaInput, meta: RequestMetadata = {}): Promise<Academia> {
    const { academia } = await this.provisioningService.provision(input, meta);
    return academia;
  }

  async list(query: ListAcademiasQueryDto): Promise<PaginatedAcademias> {
    const where = query.status ? { status: query.status } : {};

    const [items, total] = await Promise.all([
      this.prisma.academia.findMany({
        where,
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.academia.count({ where }),
    ]);

    return { items, total, page: query.page, pageSize: query.pageSize };
  }

  async findOne(id: string): Promise<Academia> {
    const academia = await this.prisma.academia.findUnique({ where: { id } });
    if (!academia) {
      throw new NotFoundException('Academia não encontrada');
    }
    return academia;
  }

  async update(
    id: string,
    dto: UpdateAcademiaDto,
    meta: RequestMetadata = {},
  ): Promise<Academia> {
    await this.findOne(id);

    const academia = await this.prisma.academia.update({ where: { id }, data: dto });

    await this.auditService.record({
      action: AuditAction.ACADEMIA_UPDATED,
      academiaId: id,
      userId: this.tenantContext.getUserId(),
      metadata: { camposAlterados: Object.keys(dto) },
      ...meta,
    });

    return academia;
  }

  /// Transições de status não têm restrição de máquina de estados nesta
  /// sprint (qualquer status -> qualquer status, decisão do SYSTEM_ADMIN) —
  /// mas entrar num status bloqueante revoga em cascata todas as sessões
  /// ativas dos usuários da academia, fechando o gap de acesso em, no
  /// máximo, a vida do access token já emitido (mesmo trade-off já aceito
  /// no Sprint 1 para troca de senha — ver docs/11-security.md). As duas
  /// escritas (status da Academia + revogação em cascata) vão na mesma
  /// $transaction: sem isso, uma falha entre elas deixaria a academia
  /// bloqueada com sessões de usuário ainda válidas — exatamente o cenário
  /// que este método existe para fechar.
  async updateStatus(
    id: string,
    dto: UpdateAcademiaStatusDto,
    meta: RequestMetadata = {},
  ): Promise<Academia> {
    const antes = await this.findOne(id);

    const { academia, sessoesRevogadas } = await this.prisma.$transaction(async (tx) => {
      const academiaAtualizada = await tx.academia.update({
        where: { id },
        data: { status: dto.status },
      });

      let revogadas = 0;
      if (isAcademiaStatusBlocking(dto.status)) {
        const resultado = await tx.refreshToken.updateMany({
          where: { user: { academiaId: id }, revokedAt: null },
          data: { revokedAt: new Date() },
        });
        revogadas = resultado.count;
      }

      return { academia: academiaAtualizada, sessoesRevogadas: revogadas };
    });

    await this.auditService.record({
      action: AuditAction.ACADEMIA_STATUS_CHANGED,
      academiaId: id,
      userId: this.tenantContext.getUserId(),
      metadata: {
        statusAnterior: antes.status,
        statusNovo: dto.status,
        motivo: dto.motivo,
        sessoesRevogadas,
      },
      ...meta,
    });

    return academia;
  }
}
