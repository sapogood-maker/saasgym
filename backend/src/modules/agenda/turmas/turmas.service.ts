import { Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction, Prisma } from '@prisma/client';
import { CreateTurmaDto } from './dto/create-turma.dto';
import { UpdateTurmaDto } from './dto/update-turma.dto';
import { UpdateTurmaStatusDto } from './dto/update-turma-status.dto';
import { ListTurmasQueryDto } from './dto/list-turmas-query.dto';
import { PaginatedTurmasResponseDto, TurmaResponseDto } from './dto/turma-response.dto';
import { TenantContextService } from '../../../common/context/tenant-context.service';
import { RequestMetadata } from '../../../common/utils/request-metadata';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuditService } from '../../audit/audit.service';

/// Projeção de leitura pro frontend (nome da modalidade/professor) — mesmo
/// motivo/padrão de `matriculaInclude` em MatriculasService.
const turmaInclude = {
  modalidade: { select: { nome: true } },
  professor: { select: { nome: true } },
} satisfies Prisma.TurmaInclude;

type TurmaComRelacoes = Prisma.TurmaGetPayload<{ include: typeof turmaInclude }>;

/// CRUD de Turma — só o agrupamento lógico (nome, modalidade, professor
/// titular, capacidade, local, status). Turma não representa aula,
/// horário, recorrência nem presença — ver docs/18-modulo-4-agenda-analise.md,
/// seção 2 item 2 ("O papel de Turma no domínio"). Recorrência/Aula/
/// TurmaAluno entram nos MS seguintes (MS4/MS6/MS5), sem nenhum
/// antecipado aqui.
@Injectable()
export class TurmasService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async create(dto: CreateTurmaDto, meta: RequestMetadata = {}): Promise<TurmaResponseDto> {
    const academiaId = this.tenantContext.getAcademiaId() as string;

    await this.garantirModalidadeExiste(dto.modalidadeId);
    await this.garantirProfessorExiste(dto.professorId);

    const turma = await this.prisma.forTenant().turma.create({
      data: { ...dto } as Prisma.TurmaUncheckedCreateInput,
      include: turmaInclude,
    });

    await this.auditService.record({
      action: AuditAction.TURMA_CREATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { turmaId: turma.id },
      ...meta,
    });

    return this.toResponse(turma);
  }

  async list(query: ListTurmasQueryDto): Promise<PaginatedTurmasResponseDto> {
    const where: Prisma.TurmaWhereInput = { deletedAt: null };
    if (query.status) {
      where.status = query.status;
    }
    if (query.search) {
      where.nome = { contains: query.search, mode: 'insensitive' };
    }

    const [items, total] = await Promise.all([
      this.prisma.forTenant().turma.findMany({
        where,
        include: turmaInclude,
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: { nome: 'asc' },
      }),
      this.prisma.forTenant().turma.count({ where }),
    ]);

    return {
      items: items.map((turma) => this.toResponse(turma)),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  async findOne(id: string): Promise<TurmaResponseDto> {
    return this.toResponse(await this.findOrThrow(id));
  }

  async update(
    id: string,
    dto: UpdateTurmaDto,
    meta: RequestMetadata = {},
  ): Promise<TurmaResponseDto> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    if (dto.modalidadeId) {
      await this.garantirModalidadeExiste(dto.modalidadeId);
    }
    if (dto.professorId) {
      await this.garantirProfessorExiste(dto.professorId);
    }

    const turma = await this.prisma.forTenant().turma.update({
      where: { id },
      data: dto,
      include: turmaInclude,
    });

    await this.auditService.record({
      action: AuditAction.TURMA_UPDATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { turmaId: id, camposAlterados: Object.keys(dto) },
      ...meta,
    });

    return this.toResponse(turma);
  }

  async updateStatus(
    id: string,
    dto: UpdateTurmaStatusDto,
    meta: RequestMetadata = {},
  ): Promise<TurmaResponseDto> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const turma = await this.prisma.forTenant().turma.update({
      where: { id },
      data: { status: dto.status },
      include: turmaInclude,
    });

    await this.auditService.record({
      action: AuditAction.TURMA_STATUS_CHANGED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { turmaId: id, statusNovo: dto.status, motivo: dto.motivo },
      ...meta,
    });

    return this.toResponse(turma);
  }

  async remove(id: string, meta: RequestMetadata = {}): Promise<void> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    await this.prisma.forTenant().turma.update({ where: { id }, data: { deletedAt: new Date() } });

    await this.auditService.record({
      action: AuditAction.TURMA_DELETED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { turmaId: id },
      ...meta,
    });
  }

  private async garantirModalidadeExiste(modalidadeId: string): Promise<void> {
    const modalidade = await this.prisma
      .forTenant()
      .modalidade.findFirst({ where: { id: modalidadeId, deletedAt: null } });
    if (!modalidade) {
      throw new NotFoundException('Modalidade não encontrada');
    }
  }

  private async garantirProfessorExiste(professorId: string): Promise<void> {
    const professor = await this.prisma
      .forTenant()
      .professor.findFirst({ where: { id: professorId, deletedAt: null } });
    if (!professor) {
      throw new NotFoundException('Professor não encontrado');
    }
  }

  private async findOrThrow(id: string): Promise<TurmaComRelacoes> {
    const turma = await this.prisma
      .forTenant()
      .turma.findFirst({ where: { id, deletedAt: null }, include: turmaInclude });
    if (!turma) {
      throw new NotFoundException('Turma não encontrada');
    }
    return turma;
  }

  private toResponse(turma: TurmaComRelacoes): TurmaResponseDto {
    return {
      id: turma.id,
      nome: turma.nome,
      modalidadeId: turma.modalidadeId,
      modalidadeNome: turma.modalidade.nome,
      professorId: turma.professorId,
      professorNome: turma.professor.nome,
      capacidadeMaxima: turma.capacidadeMaxima,
      local: turma.local,
      status: turma.status,
      createdAt: turma.createdAt,
    };
  }
}
