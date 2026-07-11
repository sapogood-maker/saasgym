import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction, Plano, Prisma } from '@prisma/client';
import { CreatePlanoDto } from './dto/create-plano.dto';
import { PaginatedPlanosResponseDto, PlanoResponseDto } from './dto/plano-response.dto';
import { ListPlanosQueryDto } from './dto/list-planos-query.dto';
import { UpdatePlanoDto } from './dto/update-plano.dto';
import { UpdatePlanoStatusDto } from './dto/update-plano-status.dto';
import { TenantContextService } from '../../common/context/tenant-context.service';
import { RequestMetadata } from '../../common/utils/request-metadata';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';

/// CRUD de Plano — mesmo padrão de AlunosService/ProfessoresService
/// (prisma.forTenant(), soft delete filtrado no service, audit log em
/// toda escrita). Sem upload de foto (não existe pro domínio). `valor` é
/// `Decimal` no banco — sempre convertido pra `number` em `toResponse()`,
/// nunca vazado como Decimal.js pro cliente HTTP.
@Injectable()
export class PlanosService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async create(dto: CreatePlanoDto, meta: RequestMetadata = {}): Promise<PlanoResponseDto> {
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const plano = await this.criarOuRelancar(() =>
      this.prisma.forTenant().plano.create({
        // academiaId é injetado em tempo de execução pela extensão de
        // tenant (forTenant()) — mesmo padrão de Aluno/Professor.
        data: { ...dto } as Prisma.PlanoUncheckedCreateInput,
      }),
    );

    await this.auditService.record({
      action: AuditAction.PLANO_CREATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { planoId: plano.id },
      ...meta,
    });

    return this.toResponse(plano);
  }

  async list(query: ListPlanosQueryDto): Promise<PaginatedPlanosResponseDto> {
    const where: Prisma.PlanoWhereInput = { deletedAt: null };
    if (query.status) {
      where.status = query.status;
    }
    if (query.search) {
      where.nome = { contains: query.search, mode: 'insensitive' };
    }

    const [items, total] = await Promise.all([
      this.prisma.forTenant().plano.findMany({
        where,
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: [{ ordem: 'asc' }, { nome: 'asc' }],
      }),
      this.prisma.forTenant().plano.count({ where }),
    ]);

    return {
      items: items.map((plano) => this.toResponse(plano)),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  async findOne(id: string): Promise<PlanoResponseDto> {
    return this.toResponse(await this.findOrThrow(id));
  }

  async update(
    id: string,
    dto: UpdatePlanoDto,
    meta: RequestMetadata = {},
  ): Promise<PlanoResponseDto> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const plano = await this.criarOuRelancar(() =>
      this.prisma.forTenant().plano.update({ where: { id }, data: dto }),
    );

    await this.auditService.record({
      action: AuditAction.PLANO_UPDATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { planoId: id, camposAlterados: Object.keys(dto) },
      ...meta,
    });

    return this.toResponse(plano);
  }

  async updateStatus(
    id: string,
    dto: UpdatePlanoStatusDto,
    meta: RequestMetadata = {},
  ): Promise<PlanoResponseDto> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const plano = await this.prisma.forTenant().plano.update({
      where: { id },
      data: { status: dto.status },
    });

    await this.auditService.record({
      action: AuditAction.PLANO_STATUS_CHANGED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { planoId: id, statusNovo: dto.status, motivo: dto.motivo },
      ...meta,
    });

    return this.toResponse(plano);
  }

  async remove(id: string, meta: RequestMetadata = {}): Promise<void> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    await this.prisma.forTenant().plano.update({ where: { id }, data: { deletedAt: new Date() } });

    await this.auditService.record({
      action: AuditAction.PLANO_DELETED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { planoId: id },
      ...meta,
    });
  }

  private async findOrThrow(id: string): Promise<Plano> {
    const plano = await this.prisma.forTenant().plano.findFirst({ where: { id, deletedAt: null } });
    if (!plano) {
      throw new NotFoundException('Plano não encontrado');
    }
    return plano;
  }

  /// P2002 aqui só pode ser o índice composto (academiaId, nome) — nome
  /// de plano duplicado dentro da mesma academia.
  private async criarOuRelancar(operacao: () => Promise<Plano>): Promise<Plano> {
    try {
      return await operacao();
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('Já existe um plano com este nome nesta academia');
      }
      throw error;
    }
  }

  private toResponse(plano: Plano): PlanoResponseDto {
    return {
      id: plano.id,
      nome: plano.nome,
      descricao: plano.descricao,
      periodicidade: plano.periodicidade,
      valor: Number(plano.valor),
      quantidadeAulas: plano.quantidadeAulas,
      ordem: plano.ordem,
      status: plano.status,
      createdAt: plano.createdAt,
    };
  }
}
