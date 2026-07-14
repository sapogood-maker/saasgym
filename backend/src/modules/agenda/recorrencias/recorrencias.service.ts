import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction, Prisma, RecorrenciaTipo } from '@prisma/client';
import { CreateRecorrenciaDto } from './dto/create-recorrencia.dto';
import { UpdateRecorrenciaDto } from './dto/update-recorrencia.dto';
import { RecorrenciaResponseDto } from './dto/recorrencia-response.dto';
import { TenantContextService } from '../../../common/context/tenant-context.service';
import { RequestMetadata } from '../../../common/utils/request-metadata';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuditService } from '../../audit/audit.service';

const recorrenciaInclude = {
  professor: { select: { nome: true } },
} satisfies Prisma.RecorrenciaInclude;

type RecorrenciaComRelacoes = Prisma.RecorrenciaGetPayload<{ include: typeof recorrenciaInclude }>;

/// CRUD de Recorrencia, sempre aninhado numa Turma — nunca um recurso de
/// topo próprio. Reforça em código as duas invariantes registradas em
/// docs/18 (seção 2 item 3): (1) `turmaId` só chega pela rota
/// (`agenda/turmas/:turmaId/recorrencias`), nunca pelo corpo — Recorrência
/// não pertence ao Professor, só à Turma; (2) nenhuma unicidade por
/// `turmaId` — uma Turma tem quantas Recorrências fizerem sentido, cada
/// uma um padrão independente de geração de aula (MS6).
@Injectable()
export class RecorrenciasService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async create(
    turmaId: string,
    dto: CreateRecorrenciaDto,
    meta: RequestMetadata = {},
  ): Promise<RecorrenciaResponseDto> {
    await this.garantirTurmaExiste(turmaId);
    if (dto.professorId) {
      await this.garantirProfessorExiste(dto.professorId);
    }
    this.validarCampoDoTipo(dto.tipo, dto);

    const academiaId = this.tenantContext.getAcademiaId() as string;

    const recorrencia = await this.prisma.forTenant().recorrencia.create({
      data: {
        ...dto,
        turmaId,
        dataInicioVigencia: new Date(dto.dataInicioVigencia),
        dataFimVigencia: dto.dataFimVigencia ? new Date(dto.dataFimVigencia) : undefined,
      } as Prisma.RecorrenciaUncheckedCreateInput,
      include: recorrenciaInclude,
    });

    await this.auditService.record({
      action: AuditAction.RECORRENCIA_CREATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { recorrenciaId: recorrencia.id, turmaId },
      ...meta,
    });

    return this.toResponse(recorrencia);
  }

  async list(turmaId: string): Promise<RecorrenciaResponseDto[]> {
    await this.garantirTurmaExiste(turmaId);

    const recorrencias = await this.prisma.forTenant().recorrencia.findMany({
      where: { turmaId, deletedAt: null },
      include: recorrenciaInclude,
      orderBy: { createdAt: 'asc' },
    });

    return recorrencias.map((recorrencia) => this.toResponse(recorrencia));
  }

  async update(
    turmaId: string,
    id: string,
    dto: UpdateRecorrenciaDto,
    meta: RequestMetadata = {},
  ): Promise<RecorrenciaResponseDto> {
    const existente = await this.findOrThrow(turmaId, id);
    if (dto.professorId) {
      await this.garantirProfessorExiste(dto.professorId);
    }

    const tipoEfetivo = dto.tipo ?? existente.tipo;
    this.validarCampoDoTipo(tipoEfetivo, {
      diaSemana: dto.diaSemana ?? existente.diaSemana ?? undefined,
      diaDoMes: dto.diaDoMes ?? existente.diaDoMes ?? undefined,
      intervaloDias: dto.intervaloDias ?? existente.intervaloDias ?? undefined,
    });

    const academiaId = this.tenantContext.getAcademiaId() as string;

    const recorrencia = await this.prisma.forTenant().recorrencia.update({
      where: { id },
      data: {
        ...dto,
        dataInicioVigencia: dto.dataInicioVigencia ? new Date(dto.dataInicioVigencia) : undefined,
        dataFimVigencia: dto.dataFimVigencia ? new Date(dto.dataFimVigencia) : undefined,
      },
      include: recorrenciaInclude,
    });

    await this.auditService.record({
      action: AuditAction.RECORRENCIA_UPDATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { recorrenciaId: id, turmaId, camposAlterados: Object.keys(dto) },
      ...meta,
    });

    return this.toResponse(recorrencia);
  }

  async remove(turmaId: string, id: string, meta: RequestMetadata = {}): Promise<void> {
    await this.findOrThrow(turmaId, id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    await this.prisma.forTenant().recorrencia.update({
      where: { id },
      data: { deletedAt: new Date() },
    });

    await this.auditService.record({
      action: AuditAction.RECORRENCIA_DELETED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { recorrenciaId: id, turmaId },
      ...meta,
    });
  }

  /// Garante que só o campo relevante ao `tipo` esteja presente — mesmo
  /// numa atualização parcial que não reenvia `tipo` (docs/18, seção 2
  /// item 3). Não valida ausência dos outros dois: dado legado de uma
  /// troca de tipo anterior não é motivo de erro, só o campo exigido pelo
  /// tipo efetivo precisa existir.
  private validarCampoDoTipo(
    tipo: RecorrenciaTipo,
    campos: { diaSemana?: number; diaDoMes?: number; intervaloDias?: number },
  ): void {
    if (tipo === RecorrenciaTipo.SEMANAL && campos.diaSemana === undefined) {
      throw new BadRequestException('diaSemana é obrigatório quando tipo = SEMANAL');
    }
    if (tipo === RecorrenciaTipo.MENSAL && campos.diaDoMes === undefined) {
      throw new BadRequestException('diaDoMes é obrigatório quando tipo = MENSAL');
    }
    if (tipo === RecorrenciaTipo.INTERVALADA && campos.intervaloDias === undefined) {
      throw new BadRequestException('intervaloDias é obrigatório quando tipo = INTERVALADA');
    }
  }

  private async garantirTurmaExiste(turmaId: string): Promise<void> {
    const turma = await this.prisma.forTenant().turma.findFirst({ where: { id: turmaId, deletedAt: null } });
    if (!turma) {
      throw new NotFoundException('Turma não encontrada');
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

  /// Além de existir, a Recorrência precisa pertencer à Turma da rota —
  /// reforça em runtime a invariante 1 (docs/18, seção 2 item 3): não dá
  /// pra editar/remover uma Recorrência de outra Turma só por adivinhar o
  /// `id`, mesmo estando na mesma academia.
  private async findOrThrow(turmaId: string, id: string): Promise<RecorrenciaComRelacoes> {
    const recorrencia = await this.prisma
      .forTenant()
      .recorrencia.findFirst({ where: { id, turmaId, deletedAt: null }, include: recorrenciaInclude });
    if (!recorrencia) {
      throw new NotFoundException('Recorrência não encontrada');
    }
    return recorrencia;
  }

  private toResponse(recorrencia: RecorrenciaComRelacoes): RecorrenciaResponseDto {
    return {
      id: recorrencia.id,
      turmaId: recorrencia.turmaId,
      tipo: recorrencia.tipo,
      diaSemana: recorrencia.diaSemana,
      diaDoMes: recorrencia.diaDoMes,
      intervaloDias: recorrencia.intervaloDias,
      horaInicio: recorrencia.horaInicio,
      duracaoMinutos: recorrencia.duracaoMinutos,
      professorId: recorrencia.professorId,
      professorNome: recorrencia.professor?.nome ?? null,
      dataInicioVigencia: recorrencia.dataInicioVigencia,
      dataFimVigencia: recorrencia.dataFimVigencia,
      ativo: recorrencia.ativo,
      createdAt: recorrencia.createdAt,
    };
  }
}
