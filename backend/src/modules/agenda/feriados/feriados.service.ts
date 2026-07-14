import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction, Feriado, Prisma } from '@prisma/client';
import { CreateFeriadoDto } from './dto/create-feriado.dto';
import { UpdateFeriadoDto } from './dto/update-feriado.dto';
import { ListFeriadosQueryDto } from './dto/list-feriados-query.dto';
import { FeriadoResponseDto, PaginatedFeriadosResponseDto } from './dto/feriado-response.dto';
import { TenantContextService } from '../../../common/context/tenant-context.service';
import { RequestMetadata } from '../../../common/utils/request-metadata';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuditService } from '../../audit/audit.service';

/// Cadastro próprio por academia, datas explícitas — sem repetição
/// automática anual nesta fase (docs/18-modulo-4-agenda-analise.md, seção
/// 2 item 8). O cancelamento em cascata de `Aula`s já geradas na data
/// (decisão confirmada) só é adicionado aqui a partir do MS7, quando
/// `AulasService` existir — este service (MS1) é só o cadastro.
@Injectable()
export class FeriadosService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async create(dto: CreateFeriadoDto, meta: RequestMetadata = {}): Promise<FeriadoResponseDto> {
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const feriado = await this.criarOuRelancar(() =>
      this.prisma.forTenant().feriado.create({
        data: {
          nome: dto.nome,
          data: new Date(dto.data),
        } as Prisma.FeriadoUncheckedCreateInput,
      }),
    );

    await this.auditService.record({
      action: AuditAction.FERIADO_CREATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { feriadoId: feriado.id, data: dto.data },
      ...meta,
    });

    return this.toResponse(feriado);
  }

  async list(query: ListFeriadosQueryDto): Promise<PaginatedFeriadosResponseDto> {
    const where: Prisma.FeriadoWhereInput = { deletedAt: null };

    const [items, total] = await Promise.all([
      this.prisma.forTenant().feriado.findMany({
        where,
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: { data: 'asc' },
      }),
      this.prisma.forTenant().feriado.count({ where }),
    ]);

    return {
      items: items.map((feriado) => this.toResponse(feriado)),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  async findOne(id: string): Promise<FeriadoResponseDto> {
    return this.toResponse(await this.findOrThrow(id));
  }

  async update(
    id: string,
    dto: UpdateFeriadoDto,
    meta: RequestMetadata = {},
  ): Promise<FeriadoResponseDto> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const feriado = await this.criarOuRelancar(() =>
      this.prisma.forTenant().feriado.update({
        where: { id },
        data: {
          ...(dto.nome && { nome: dto.nome }),
          ...(dto.data && { data: new Date(dto.data) }),
        },
      }),
    );

    await this.auditService.record({
      action: AuditAction.FERIADO_UPDATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { feriadoId: id, camposAlterados: Object.keys(dto) },
      ...meta,
    });

    return this.toResponse(feriado);
  }

  async remove(id: string, meta: RequestMetadata = {}): Promise<void> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    await this.prisma
      .forTenant()
      .feriado.update({ where: { id }, data: { deletedAt: new Date() } });

    await this.auditService.record({
      action: AuditAction.FERIADO_DELETED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { feriadoId: id },
      ...meta,
    });
  }

  private async findOrThrow(id: string): Promise<Feriado> {
    const feriado = await this.prisma
      .forTenant()
      .feriado.findFirst({ where: { id, deletedAt: null } });
    if (!feriado) {
      throw new NotFoundException('Feriado não encontrado');
    }
    return feriado;
  }

  /// P2002 aqui só pode ser o índice composto (academiaId, data) — já
  /// existe um feriado cadastrado para esta data nesta academia.
  private async criarOuRelancar(operacao: () => Promise<Feriado>): Promise<Feriado> {
    try {
      return await operacao();
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('Já existe um feriado cadastrado para esta data');
      }
      throw error;
    }
  }

  private toResponse(feriado: Feriado): FeriadoResponseDto {
    return {
      id: feriado.id,
      nome: feriado.nome,
      data: feriado.data,
      createdAt: feriado.createdAt,
    };
  }
}
