import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction, Modalidade, Prisma } from '@prisma/client';
import { CreateModalidadeDto } from './dto/create-modalidade.dto';
import { UpdateModalidadeDto } from './dto/update-modalidade.dto';
import { UpdateModalidadeStatusDto } from './dto/update-modalidade-status.dto';
import { ListModalidadesQueryDto } from './dto/list-modalidades-query.dto';
import {
  ModalidadeResponseDto,
  PaginatedModalidadesResponseDto,
} from './dto/modalidade-response.dto';
import { TenantContextService } from '../../../common/context/tenant-context.service';
import { RequestMetadata } from '../../../common/utils/request-metadata';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuditService } from '../../audit/audit.service';

/// CRUD de Modalidade — mesmo padrão de PlanosService (prisma.forTenant(),
/// soft delete filtrado no service, audit log em toda escrita). Categoria
/// de aula (docs/18-modulo-4-agenda-analise.md, seção 2 item 1) — entidade
/// própria porque a mesma modalidade reaparece em várias Turmas reais.
@Injectable()
export class ModalidadesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async create(
    dto: CreateModalidadeDto,
    meta: RequestMetadata = {},
  ): Promise<ModalidadeResponseDto> {
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const modalidade = await this.criarOuRelancar(() =>
      this.prisma.forTenant().modalidade.create({
        data: { ...dto } as Prisma.ModalidadeUncheckedCreateInput,
      }),
    );

    await this.auditService.record({
      action: AuditAction.MODALIDADE_CREATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { modalidadeId: modalidade.id },
      ...meta,
    });

    return this.toResponse(modalidade);
  }

  async list(query: ListModalidadesQueryDto): Promise<PaginatedModalidadesResponseDto> {
    const where: Prisma.ModalidadeWhereInput = { deletedAt: null };
    if (query.status) {
      where.status = query.status;
    }
    if (query.search) {
      where.nome = { contains: query.search, mode: 'insensitive' };
    }

    const [items, total] = await Promise.all([
      this.prisma.forTenant().modalidade.findMany({
        where,
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: { nome: 'asc' },
      }),
      this.prisma.forTenant().modalidade.count({ where }),
    ]);

    return {
      items: items.map((modalidade) => this.toResponse(modalidade)),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  async findOne(id: string): Promise<ModalidadeResponseDto> {
    return this.toResponse(await this.findOrThrow(id));
  }

  async update(
    id: string,
    dto: UpdateModalidadeDto,
    meta: RequestMetadata = {},
  ): Promise<ModalidadeResponseDto> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const modalidade = await this.criarOuRelancar(() =>
      this.prisma.forTenant().modalidade.update({ where: { id }, data: dto }),
    );

    await this.auditService.record({
      action: AuditAction.MODALIDADE_UPDATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { modalidadeId: id, camposAlterados: Object.keys(dto) },
      ...meta,
    });

    return this.toResponse(modalidade);
  }

  async updateStatus(
    id: string,
    dto: UpdateModalidadeStatusDto,
    meta: RequestMetadata = {},
  ): Promise<ModalidadeResponseDto> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const modalidade = await this.prisma.forTenant().modalidade.update({
      where: { id },
      data: { status: dto.status },
    });

    await this.auditService.record({
      action: AuditAction.MODALIDADE_STATUS_CHANGED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { modalidadeId: id, statusNovo: dto.status, motivo: dto.motivo },
      ...meta,
    });

    return this.toResponse(modalidade);
  }

  async remove(id: string, meta: RequestMetadata = {}): Promise<void> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    await this.prisma
      .forTenant()
      .modalidade.update({ where: { id }, data: { deletedAt: new Date() } });

    await this.auditService.record({
      action: AuditAction.MODALIDADE_DELETED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { modalidadeId: id },
      ...meta,
    });
  }

  private async findOrThrow(id: string): Promise<Modalidade> {
    const modalidade = await this.prisma
      .forTenant()
      .modalidade.findFirst({ where: { id, deletedAt: null } });
    if (!modalidade) {
      throw new NotFoundException('Modalidade não encontrada');
    }
    return modalidade;
  }

  /// P2002 aqui só pode ser o índice composto (academiaId, nome) — nome
  /// de modalidade duplicado dentro da mesma academia.
  private async criarOuRelancar(operacao: () => Promise<Modalidade>): Promise<Modalidade> {
    try {
      return await operacao();
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('Já existe uma modalidade com este nome nesta academia');
      }
      throw error;
    }
  }

  private toResponse(modalidade: Modalidade): ModalidadeResponseDto {
    return {
      id: modalidade.id,
      nome: modalidade.nome,
      cor: modalidade.cor,
      status: modalidade.status,
      createdAt: modalidade.createdAt,
    };
  }
}
