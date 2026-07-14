import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AulaStatus, AuditAction, Prisma } from '@prisma/client';
import { RegistrarPresencaDto } from './dto/registrar-presenca.dto';
import { AulaAlunoResponseDto } from './dto/aula-aluno-response.dto';
import { ListFrequenciaQueryDto } from './dto/list-frequencia-query.dto';
import {
  FrequenciaAlunoResponseDto,
  PaginatedFrequenciaAlunoResponseDto,
} from './dto/frequencia-aluno-response.dto';
import { TenantContextService } from '../../../common/context/tenant-context.service';
import { RequestMetadata } from '../../../common/utils/request-metadata';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuditService } from '../../audit/audit.service';

const aulaAlunoInclude = {
  aluno: { select: { nome: true } },
} satisfies Prisma.AulaAlunoInclude;

type AulaAlunoComRelacoes = Prisma.AulaAlunoGetPayload<{ include: typeof aulaAlunoInclude }>;

const frequenciaInclude = {
  aula: { select: { data: true, status: true, turmaId: true, turma: { select: { nome: true } } } },
} satisfies Prisma.AulaAlunoInclude;

type AulaAlunoComAula = Prisma.AulaAlunoGetPayload<{ include: typeof frequenciaInclude }>;

/// Frequência (MS8) — **invariantes explícitas antes de qualquer código
/// (docs/18, seção 5, "Frequência")**:
///
/// 1. A presença pertence exclusivamente a `AulaAluno` — nunca a `Aula`,
///    `Turma` ou `Matricula`.
/// 2. Registrar presença só escreve `AulaAluno.presenca` — nunca toca
///    `Aula`, `Turma`, `Recorrencia` ou `TurmaAluno`.
/// 3. Só `Aula`s realizadas recebem presença (`status == AGENDADA && data
///    < hoje`, mesmo cálculo de "realizada" já usado em toda a Agenda,
///    nunca armazenado). Aula cancelada ou futura sempre bloqueia.
/// 4. Frequência é fato histórico — mudanças futuras em Matricula/Turma/
///    Professor nunca alteram uma presença já registrada (o service nem
///    lê essas entidades pra decidir o valor de `presenca`).
@Injectable()
export class AulaAlunosService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async listPorAula(aulaId: string): Promise<AulaAlunoResponseDto[]> {
    await this.garantirAulaExiste(aulaId);

    const aulaAlunos = await this.prisma.forTenant().aulaAluno.findMany({
      where: { aulaId, deletedAt: null },
      include: aulaAlunoInclude,
      orderBy: { aluno: { nome: 'asc' } },
    });

    return aulaAlunos.map((aulaAluno) => this.toResponse(aulaAluno));
  }

  async listPorAluno(
    alunoId: string,
    query: ListFrequenciaQueryDto,
  ): Promise<PaginatedFrequenciaAlunoResponseDto> {
    await this.garantirAlunoExiste(alunoId);

    const where: Prisma.AulaAlunoWhereInput = { alunoId, deletedAt: null };
    if (query.dataInicio || query.dataFim) {
      where.aula = {
        data: {
          ...(query.dataInicio ? { gte: new Date(query.dataInicio) } : {}),
          ...(query.dataFim ? { lte: new Date(query.dataFim) } : {}),
        },
      };
    }

    const [items, total] = await Promise.all([
      this.prisma.forTenant().aulaAluno.findMany({
        where,
        include: frequenciaInclude,
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: { aula: { data: 'desc' } },
      }),
      this.prisma.forTenant().aulaAluno.count({ where }),
    ]);

    return {
      items: items.map((aulaAluno) => this.toFrequenciaResponse(aulaAluno)),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  async registrarPresenca(
    aulaId: string,
    id: string,
    dto: RegistrarPresencaDto,
    meta: RequestMetadata = {},
  ): Promise<AulaAlunoResponseDto> {
    const aula = await this.garantirAulaExiste(aulaId);
    this.garantirAulaRealizada(aula);
    const atual = await this.findOrThrow(aulaId, id);

    const academiaId = this.tenantContext.getAcademiaId() as string;

    const aulaAluno = await this.prisma.forTenant().aulaAluno.update({
      where: { id },
      data: { presenca: dto.presenca },
      include: aulaAlunoInclude,
    });

    await this.auditService.record({
      action: AuditAction.AULA_ALUNO_PRESENCA_MARCADA,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: {
        aulaAlunoId: id,
        aulaId,
        alunoId: atual.alunoId,
        presencaAnterior: atual.presenca,
        presencaNova: dto.presenca,
      },
      ...meta,
    });

    return this.toResponse(aulaAluno);
  }

  private async garantirAulaExiste(aulaId: string) {
    const aula = await this.prisma.forTenant().aula.findFirst({ where: { id: aulaId, deletedAt: null } });
    if (!aula) {
      throw new NotFoundException('Aula não encontrada');
    }
    return aula;
  }

  private async garantirAlunoExiste(alunoId: string): Promise<void> {
    const aluno = await this.prisma.forTenant().aluno.findFirst({ where: { id: alunoId, deletedAt: null } });
    if (!aluno) {
      throw new NotFoundException('Aluno não encontrado');
    }
  }

  /// "Realizada" — mesmo cálculo usado em toda a Agenda, nunca armazenado
  /// (docs/18, seção 2 item 4): `status == AGENDADA && data < hoje`.
  private garantirAulaRealizada(aula: { status: AulaStatus; data: Date }): void {
    if (aula.status === AulaStatus.CANCELADA) {
      throw new BadRequestException('Não é possível registrar presença numa aula cancelada');
    }
    const hoje = new Date();
    const inicioHoje = new Date(Date.UTC(hoje.getUTCFullYear(), hoje.getUTCMonth(), hoje.getUTCDate()));
    if (aula.data.getTime() >= inicioHoje.getTime()) {
      throw new BadRequestException('Só é possível registrar presença de aulas já realizadas');
    }
  }

  private async findOrThrow(aulaId: string, id: string): Promise<AulaAlunoComRelacoes> {
    const aulaAluno = await this.prisma
      .forTenant()
      .aulaAluno.findFirst({ where: { id, aulaId, deletedAt: null }, include: aulaAlunoInclude });
    if (!aulaAluno) {
      throw new NotFoundException('Inscrição na aula não encontrada');
    }
    return aulaAluno;
  }

  private toResponse(aulaAluno: AulaAlunoComRelacoes): AulaAlunoResponseDto {
    return {
      id: aulaAluno.id,
      aulaId: aulaAluno.aulaId,
      alunoId: aulaAluno.alunoId,
      alunoNome: aulaAluno.aluno.nome,
      turmaAlunoId: aulaAluno.turmaAlunoId,
      tipo: aulaAluno.tipo,
      presenca: aulaAluno.presenca,
      createdAt: aulaAluno.createdAt,
    };
  }

  private toFrequenciaResponse(aulaAluno: AulaAlunoComAula): FrequenciaAlunoResponseDto {
    return {
      id: aulaAluno.id,
      aulaId: aulaAluno.aulaId,
      aulaData: aulaAluno.aula.data,
      aulaStatus: aulaAluno.aula.status,
      turmaId: aulaAluno.aula.turmaId,
      turmaNome: aulaAluno.aula.turma.nome,
      tipo: aulaAluno.tipo,
      presenca: aulaAluno.presenca,
      createdAt: aulaAluno.createdAt,
    };
  }
}
