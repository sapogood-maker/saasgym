import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction, MatriculaStatus, Prisma, UserStatus } from '@prisma/client';
import { CreateTurmaAlunoDto } from './dto/create-turma-aluno.dto';
import { UpdateTurmaAlunoStatusDto } from './dto/update-turma-aluno-status.dto';
import { TurmaAlunoResponseDto } from './dto/turma-aluno-response.dto';
import { TenantContextService } from '../../../common/context/tenant-context.service';
import { RequestMetadata } from '../../../common/utils/request-metadata';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuditService } from '../../audit/audit.service';

const turmaAlunoInclude = {
  aluno: { select: { nome: true } },
} satisfies Prisma.TurmaAlunoInclude;

type TurmaAlunoComRelacoes = Prisma.TurmaAlunoGetPayload<{ include: typeof turmaAlunoInclude }>;

/// CRUD de `TurmaAluno` — a inscrição permanente do aluno na Turma.
/// **Invariante (docs/18, seção 2 item 6, MS5): este service nunca cria,
/// altera ou remove `AulaAluno`** — não referencia esse model em nenhum
/// método. A geração de `Aula`/`AulaAluno` (MS6) é responsabilidade
/// exclusiva do gerador daquele MS, que lê `TurmaAluno` mas nunca o
/// contrário; nenhuma sincronização automática entre as duas tabelas
/// existe aqui, deliberadamente.
@Injectable()
export class TurmaAlunosService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async create(
    turmaId: string,
    dto: CreateTurmaAlunoDto,
    meta: RequestMetadata = {},
  ): Promise<TurmaAlunoResponseDto> {
    const turma = await this.garantirTurmaExiste(turmaId);
    await this.garantirAlunoExiste(dto.alunoId);
    const matricula = await this.garantirAlunoElegivel(dto.alunoId);
    await this.garantirSemInscricaoAtiva(turmaId, dto.alunoId);
    await this.garantirCapacidadeDisponivel(turmaId, turma.capacidadeMaxima);

    const academiaId = this.tenantContext.getAcademiaId() as string;

    const turmaAluno = await this.prisma.forTenant().turmaAluno.create({
      data: {
        turmaId,
        alunoId: dto.alunoId,
        matriculaId: matricula.id,
      } as Prisma.TurmaAlunoUncheckedCreateInput,
      include: turmaAlunoInclude,
    });

    await this.auditService.record({
      action: AuditAction.TURMA_ALUNO_MATRICULADO,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { turmaAlunoId: turmaAluno.id, turmaId, alunoId: dto.alunoId },
      ...meta,
    });

    return this.toResponse(turmaAluno);
  }

  async list(turmaId: string): Promise<TurmaAlunoResponseDto[]> {
    await this.garantirTurmaExiste(turmaId);

    const turmaAlunos = await this.prisma.forTenant().turmaAluno.findMany({
      where: { turmaId, deletedAt: null },
      include: turmaAlunoInclude,
      orderBy: { createdAt: 'asc' },
    });

    return turmaAlunos.map((turmaAluno) => this.toResponse(turmaAluno));
  }

  async updateStatus(
    turmaId: string,
    id: string,
    dto: UpdateTurmaAlunoStatusDto,
    meta: RequestMetadata = {},
  ): Promise<TurmaAlunoResponseDto> {
    const atual = await this.findOrThrow(turmaId, id);
    if (dto.status === UserStatus.ATIVO && atual.status !== UserStatus.ATIVO) {
      await this.garantirSemInscricaoAtiva(turmaId, atual.alunoId, id);
      const turma = await this.garantirTurmaExiste(turmaId);
      await this.garantirCapacidadeDisponivel(turmaId, turma.capacidadeMaxima);
    }

    const academiaId = this.tenantContext.getAcademiaId() as string;

    const turmaAluno = await this.prisma.forTenant().turmaAluno.update({
      where: { id },
      data: {
        status: dto.status,
        dataFim: dto.status === UserStatus.INATIVO ? new Date() : null,
      },
      include: turmaAlunoInclude,
    });

    await this.auditService.record({
      action: AuditAction.TURMA_ALUNO_STATUS_CHANGED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { turmaAlunoId: id, turmaId, statusNovo: dto.status, motivo: dto.motivo },
      ...meta,
    });

    return this.toResponse(turmaAluno);
  }

  async remove(turmaId: string, id: string, meta: RequestMetadata = {}): Promise<void> {
    await this.findOrThrow(turmaId, id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    await this.prisma.forTenant().turmaAluno.update({
      where: { id },
      data: { deletedAt: new Date() },
    });

    await this.auditService.record({
      action: AuditAction.TURMA_ALUNO_REMOVIDO,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { turmaAlunoId: id, turmaId },
      ...meta,
    });
  }

  private async garantirTurmaExiste(turmaId: string) {
    const turma = await this.prisma
      .forTenant()
      .turma.findFirst({ where: { id: turmaId, deletedAt: null } });
    if (!turma) {
      throw new NotFoundException('Turma não encontrada');
    }
    return turma;
  }

  private async garantirAlunoExiste(alunoId: string): Promise<void> {
    const aluno = await this.prisma.forTenant().aluno.findFirst({ where: { id: alunoId, deletedAt: null } });
    if (!aluno) {
      throw new NotFoundException('Aluno não encontrado');
    }
  }

  /// Elegibilidade (docs/18, seção 7, item confirmado): só um aluno com
  /// `Matricula.status = ATIVA` pode ser inscrito numa Turma.
  private async garantirAlunoElegivel(alunoId: string) {
    const matricula = await this.prisma.forTenant().matricula.findFirst({
      where: { alunoId, status: MatriculaStatus.ATIVA, deletedAt: null },
    });
    if (!matricula) {
      throw new BadRequestException(
        'Aluno não possui matrícula ativa — matrícula ativa é exigida para inscrever em turma',
      );
    }
    return matricula;
  }

  /// `excluindoId` permite reativar a própria linha (status ATIVO) sem se
  /// auto-bloquear como "já inscrito".
  private async garantirSemInscricaoAtiva(
    turmaId: string,
    alunoId: string,
    excluindoId?: string,
  ): Promise<void> {
    const existente = await this.prisma.forTenant().turmaAluno.findFirst({
      where: {
        turmaId,
        alunoId,
        status: UserStatus.ATIVO,
        deletedAt: null,
        ...(excluindoId ? { id: { not: excluindoId } } : {}),
      },
    });
    if (existente) {
      throw new ConflictException('Aluno já está matriculado nesta turma');
    }
  }

  /// Só conta inscrições ATIVAS — `capacidadeMaxima` nula = ilimitada
  /// (mesma convenção de `Plano.quantidadeAulas`/`Turma.capacidadeMaxima`).
  private async garantirCapacidadeDisponivel(
    turmaId: string,
    capacidadeMaxima: number | null,
  ): Promise<void> {
    if (capacidadeMaxima === null) {
      return;
    }
    const total = await this.prisma.forTenant().turmaAluno.count({
      where: { turmaId, status: UserStatus.ATIVO, deletedAt: null },
    });
    if (total >= capacidadeMaxima) {
      throw new ConflictException('Turma atingiu a capacidade máxima de alunos');
    }
  }

  private async findOrThrow(turmaId: string, id: string): Promise<TurmaAlunoComRelacoes> {
    const turmaAluno = await this.prisma
      .forTenant()
      .turmaAluno.findFirst({ where: { id, turmaId, deletedAt: null }, include: turmaAlunoInclude });
    if (!turmaAluno) {
      throw new NotFoundException('Inscrição não encontrada');
    }
    return turmaAluno;
  }

  private toResponse(turmaAluno: TurmaAlunoComRelacoes): TurmaAlunoResponseDto {
    return {
      id: turmaAluno.id,
      turmaId: turmaAluno.turmaId,
      alunoId: turmaAluno.alunoId,
      alunoNome: turmaAluno.aluno.nome,
      matriculaId: turmaAluno.matriculaId,
      status: turmaAluno.status,
      dataInicio: turmaAluno.dataInicio,
      dataFim: turmaAluno.dataFim,
      createdAt: turmaAluno.createdAt,
    };
  }
}
