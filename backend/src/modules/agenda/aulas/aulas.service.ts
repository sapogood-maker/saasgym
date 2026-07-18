import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AulaAlunoTipo, AulaStatus, AuditAction, Prisma, UserStatus } from '@prisma/client';
import { calcularDatasCandidatas, formatarDataChave } from './aulas.util';
import { GerarAulasDto } from './dto/gerar-aulas.dto';
import { GerarAulasResponseDto } from './dto/gerar-aulas-response.dto';
import { ListAulasQueryDto } from './dto/list-aulas-query.dto';
import { ListAulasCalendarioQueryDto } from './dto/list-aulas-calendario-query.dto';
import { CancelarAulaDto } from './dto/cancelar-aula.dto';
import { DefinirSubstitutoDto } from './dto/definir-substituto.dto';
import { CreateAulaExtraDto } from './dto/create-aula-extra.dto';
import { AulaResponseDto, PaginatedAulasResponseDto } from './dto/aula-response.dto';
import { TenantContextService } from '../../../common/context/tenant-context.service';
import { RequestMetadata } from '../../../common/utils/request-metadata';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuditService } from '../../audit/audit.service';

const aulaInclude = {
  professor: { select: { nome: true } },
  turma: {
    select: { nome: true, modalidadeId: true, local: true, modalidade: { select: { nome: true } } },
  },
  // `deletedAt: null` aqui é o que faz `totalAlunos` cair quando o
  // cascade de encerramento de vínculo (docs/32,
  // `aluno-encerramento.util.ts`) remove um aluno arquivado/removido de
  // uma aula futura — sem esse filtro a ocupação continuaria contando a
  // linha "removida".
  _count: { select: { alunos: { where: { deletedAt: null } } } },
  // Sprint de UX da Agenda (docs/24, item 6): total de reposições por aula
  // pro resumo operacional — 2ª leitura da mesma relação (`alunos`,
  // filtrada por tipo), não uma consulta separada — mesma ida ao banco.
  alunos: { where: { tipo: AulaAlunoTipo.REPOSICAO, deletedAt: null }, select: { id: true } },
} satisfies Prisma.AulaInclude;

type AulaComRelacoes = Prisma.AulaGetPayload<{ include: typeof aulaInclude }>;

// Sprint "Agenda operacional" (docs/33) — só usado por `paginar()` quando
// `incluirAlunos` é pedido (Dia/Semana da Agenda). Prisma não permite
// incluir a mesma relação (`alunos`) duas vezes com filtros diferentes no
// mesmo `include`, então este é um include ALTERNATIVO (não um adicional):
// busca todos os AulaAluno ativos (não só REPOSICAO) já com o nome do
// aluno — de onde `totalReposicoes` E `alunosNomes` são derivados juntos,
// sem nenhuma consulta a mais que a variante padrão acima.
const aulaIncludeComAlunos = {
  professor: aulaInclude.professor,
  turma: aulaInclude.turma,
  _count: aulaInclude._count,
  alunos: {
    where: { deletedAt: null },
    select: { tipo: true, aluno: { select: { nome: true } } },
    orderBy: { aluno: { nome: 'asc' } },
  },
} satisfies Prisma.AulaInclude;

type AulaComAlunosDetalhados = Prisma.AulaGetPayload<{ include: typeof aulaIncludeComAlunos }>;

/// Gerador de Aulas (MS6) + Calendário (MS7) — **invariantes explícitas
/// antes de qualquer código (docs/18, seção 5)**:
///
/// Geração (MS6): nunca altera uma `Aula`/`AulaAluno` já existente, só
/// cria o que ainda não existe; determinística e idempotente.
///
/// Calendário (MS7) — `Aula` continua sendo o único fato do calendário
/// (nenhuma entidade nova); cancelar nunca remove, só muda `status`;
/// professor substituto é exceção pontual da `Aula`, nunca toca
/// `Turma`/`Recorrencia`; aula extra é sempre uma `Aula` independente
/// (`recorrenciaId = null`), nunca cria/altera `Recorrencia`. Nenhuma das
/// três operações do MS7 toca `Recorrencia`, `TurmaAluno` ou `AulaAluno`.
@Injectable()
export class AulasService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async gerar(
    turmaId: string,
    dto: GerarAulasDto,
    meta: RequestMetadata = {},
  ): Promise<GerarAulasResponseDto> {
    const turma = await this.garantirTurmaExiste(turmaId);
    const inicioPeriodo = new Date(dto.dataInicio);
    const fimPeriodo = new Date(dto.dataFim);
    if (inicioPeriodo.getTime() > fimPeriodo.getTime()) {
      throw new BadRequestException('dataInicio deve ser anterior ou igual a dataFim');
    }

    const academiaId = this.tenantContext.getAcademiaId() as string;
    const userId = this.tenantContext.getUserId() as string;

    const recorrencias = await this.prisma.forTenant().recorrencia.findMany({
      where: { turmaId, ativo: true, deletedAt: null },
    });

    const feriados = await this.prisma.forTenant().feriado.findMany({
      where: { data: { gte: inicioPeriodo, lte: fimPeriodo } },
    });
    const datasFeriado = new Set(feriados.map((feriado) => formatarDataChave(feriado.data)));

    const turmaAlunosAtivos = await this.prisma.forTenant().turmaAluno.findMany({
      where: { turmaId, status: UserStatus.ATIVO, deletedAt: null },
    });

    let geradas = 0;
    let jaExistentes = 0;

    for (const recorrencia of recorrencias) {
      const candidatas = calcularDatasCandidatas(recorrencia, inicioPeriodo, fimPeriodo).filter(
        (data) => !datasFeriado.has(formatarDataChave(data)),
      );

      for (const data of candidatas) {
        // Existência checada sem filtrar `deletedAt` — mesmo uma Aula
        // corrigida por engano (soft delete) ocupa a combinação
        // (recorrenciaId, data); recriar nesse caso é uma decisão
        // manual fora do escopo deste gerador, não deste loop.
        const existente = await this.prisma.forTenant().aula.findFirst({
          where: { recorrenciaId: recorrencia.id, data },
        });
        if (existente) {
          jaExistentes += 1;
          continue;
        }

        // $transaction: uma Aula sem seus AulaAluno (snapshot dos elegíveis
        // no momento da geração) violaria a idempotência do gerador — uma
        // 2a chamada veria a Aula já existente (linha acima) e nunca mais
        // tentaria popular os alunos. Mesmo padrão de
        // MensalidadesService.marcarPaga/MatriculasService.renovar: dentro
        // da transação, o client base (não forTenant()) exige academiaId
        // explícito.
        const aula = await this.prisma.$transaction(async (tx) => {
          const novaAula = await tx.aula.create({
            data: {
              academiaId,
              turmaId,
              recorrenciaId: recorrencia.id,
              data,
              horaInicio: recorrencia.horaInicio,
              duracaoMinutos: recorrencia.duracaoMinutos,
              professorId: recorrencia.professorId ?? turma.professorId,
              capacidadeMaxima: turma.capacidadeMaxima,
              createdByUserId: userId,
            } as Prisma.AulaUncheckedCreateInput,
          });

          if (turmaAlunosAtivos.length > 0) {
            await tx.aulaAluno.createMany({
              data: turmaAlunosAtivos.map((turmaAluno) => ({
                academiaId,
                aulaId: novaAula.id,
                alunoId: turmaAluno.alunoId,
                turmaAlunoId: turmaAluno.id,
              })) as Prisma.AulaAlunoUncheckedCreateInput[],
            });
          }

          return novaAula;
        });
        geradas += 1;
      }
    }

    await this.auditService.record({
      action: AuditAction.AULA_GERADA,
      academiaId,
      userId,
      metadata: {
        turmaId,
        dataInicio: dto.dataInicio,
        dataFim: dto.dataFim,
        geradas,
        jaExistentes,
      },
      ...meta,
    });

    return { geradas, jaExistentes };
  }

  async list(turmaId: string, query: ListAulasQueryDto): Promise<PaginatedAulasResponseDto> {
    await this.garantirTurmaExiste(turmaId);

    const where: Prisma.AulaWhereInput = { turmaId, deletedAt: null };
    if (query.dataInicio || query.dataFim) {
      where.data = {
        ...(query.dataInicio ? { gte: new Date(query.dataInicio) } : {}),
        ...(query.dataFim ? { lte: new Date(query.dataFim) } : {}),
      };
    }

    return this.paginar(where, query.page, query.pageSize, false);
  }

  /// Calendário (MS7) — lista `Aula`s de toda a academia (não aninhado
  /// numa Turma), com os 4 filtros já previstos desde a análise. `Aula`
  /// continua sendo o único fato consultado — este método só monta um
  /// `where` diferente do `list()` acima, mesma leitura.
  async listCalendario(query: ListAulasCalendarioQueryDto): Promise<PaginatedAulasResponseDto> {
    const where: Prisma.AulaWhereInput = { deletedAt: null };
    if (query.dataInicio || query.dataFim) {
      where.data = {
        ...(query.dataInicio ? { gte: new Date(query.dataInicio) } : {}),
        ...(query.dataFim ? { lte: new Date(query.dataFim) } : {}),
      };
    }
    if (query.turmaId) {
      where.turmaId = query.turmaId;
    }
    if (query.professorId) {
      where.professorId = query.professorId;
    }
    if (query.modalidadeId) {
      where.turma = { modalidadeId: query.modalidadeId };
    }
    if (query.status) {
      where.status = query.status;
    }

    return this.paginar(where, query.page, query.pageSize, query.incluirAlunos);
  }

  async findOne(id: string): Promise<AulaResponseDto> {
    return this.toResponse(await this.findOrThrow(id));
  }

  /// Cancelamento (docs/18, "Calendário — invariante 2"): só muda
  /// `status` — nunca `deletedAt`, nunca toca `AulaAluno` (histórico de
  /// quem estava inscrito continua intacto).
  async cancelar(
    id: string,
    dto: CancelarAulaDto,
    meta: RequestMetadata = {},
  ): Promise<AulaResponseDto> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const aula = await this.prisma.forTenant().aula.update({
      where: { id },
      data: { status: AulaStatus.CANCELADA, motivoCancelamento: dto.motivoCancelamento },
      include: aulaInclude,
    });

    await this.auditService.record({
      action: AuditAction.AULA_CANCELADA,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { aulaId: id, motivoCancelamento: dto.motivoCancelamento },
      ...meta,
    });

    return this.toResponse(aula);
  }

  /// Professor substituto (docs/18, "Calendário — invariante 3"): só
  /// escreve `Aula.professorId` — nunca `Turma.professorId` nem
  /// `Recorrencia.professorId`. Bloqueado numa aula cancelada (não faz
  /// sentido substituir professor de uma aula que não vai acontecer).
  async definirSubstituto(
    id: string,
    dto: DefinirSubstitutoDto,
    meta: RequestMetadata = {},
  ): Promise<AulaResponseDto> {
    const atual = await this.findOrThrow(id);
    if (atual.status === AulaStatus.CANCELADA) {
      throw new BadRequestException('Não é possível definir substituto numa aula cancelada');
    }
    await this.garantirProfessorExiste(dto.professorId);
    const academiaId = this.tenantContext.getAcademiaId() as string;
    const professorTitularId = atual.professorId;

    const aula = await this.prisma.forTenant().aula.update({
      where: { id },
      data: { professorId: dto.professorId },
      include: aulaInclude,
    });

    await this.auditService.record({
      action: AuditAction.AULA_SUBSTITUICAO,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { aulaId: id, professorTitularId, professorSubstitutoId: dto.professorId },
      ...meta,
    });

    return this.toResponse(aula);
  }

  /// Aula extra (docs/18, "Calendário — invariante 4"): sempre
  /// `recorrenciaId = null`, nunca cria/altera `Recorrencia`. Não popula
  /// `AulaAluno` automaticamente — fora do escopo do MS7 (ver seção 5).
  async criarExtra(dto: CreateAulaExtraDto, meta: RequestMetadata = {}): Promise<AulaResponseDto> {
    const turma = await this.garantirTurmaExiste(dto.turmaId);
    if (dto.professorId) {
      await this.garantirProfessorExiste(dto.professorId);
    }

    const academiaId = this.tenantContext.getAcademiaId() as string;
    const userId = this.tenantContext.getUserId() as string;

    const aula = await this.prisma.forTenant().aula.create({
      data: {
        turmaId: dto.turmaId,
        recorrenciaId: null,
        data: new Date(dto.data),
        horaInicio: dto.horaInicio,
        duracaoMinutos: dto.duracaoMinutos,
        professorId: dto.professorId ?? turma.professorId,
        capacidadeMaxima: dto.capacidadeMaxima ?? turma.capacidadeMaxima,
        createdByUserId: userId,
      } as Prisma.AulaUncheckedCreateInput,
      include: aulaInclude,
    });

    await this.auditService.record({
      action: AuditAction.AULA_EXTRA_CRIADA,
      academiaId,
      userId,
      metadata: { aulaId: aula.id, turmaId: dto.turmaId, data: dto.data },
      ...meta,
    });

    return this.toResponse(aula);
  }

  /// Correção de cadastro (docs/18, seção 3 item 11) — soft delete,
  /// nunca usado pelo fluxo normal de cancelamento (esse é `cancelar()`,
  /// que só muda `status`).
  async remove(id: string, meta: RequestMetadata = {}): Promise<void> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    await this.prisma.forTenant().aula.update({ where: { id }, data: { deletedAt: new Date() } });

    await this.auditService.record({
      action: AuditAction.AULA_DELETED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { aulaId: id },
      ...meta,
    });
  }

  private async paginar(
    where: Prisma.AulaWhereInput,
    page: number,
    pageSize: number,
    incluirAlunos: boolean,
  ): Promise<PaginatedAulasResponseDto> {
    const skip = (page - 1) * pageSize;
    const orderBy = { data: 'asc' as const };

    if (incluirAlunos) {
      const [items, total] = await Promise.all([
        this.prisma
          .forTenant()
          .aula.findMany({ where, include: aulaIncludeComAlunos, skip, take: pageSize, orderBy }),
        this.prisma.forTenant().aula.count({ where }),
      ]);
      return { items: items.map((aula) => this.toResponseComAlunos(aula)), total, page, pageSize };
    }

    const [items, total] = await Promise.all([
      this.prisma
        .forTenant()
        .aula.findMany({ where, include: aulaInclude, skip, take: pageSize, orderBy }),
      this.prisma.forTenant().aula.count({ where }),
    ]);
    return { items: items.map((aula) => this.toResponse(aula)), total, page, pageSize };
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

  private async garantirProfessorExiste(professorId: string): Promise<void> {
    const professor = await this.prisma
      .forTenant()
      .professor.findFirst({ where: { id: professorId, deletedAt: null } });
    if (!professor) {
      throw new NotFoundException('Professor não encontrado');
    }
  }

  private async findOrThrow(id: string): Promise<AulaComRelacoes> {
    const aula = await this.prisma
      .forTenant()
      .aula.findFirst({ where: { id, deletedAt: null }, include: aulaInclude });
    if (!aula) {
      throw new NotFoundException('Aula não encontrada');
    }
    return aula;
  }

  private toResponse(aula: AulaComRelacoes): AulaResponseDto {
    return {
      ...this.camposComuns(aula),
      totalReposicoes: aula.alunos.length,
      alunosNomes: [],
    };
  }

  /// Só para `paginar(..., incluirAlunos: true)` — deriva `totalReposicoes`
  /// E `alunosNomes` da MESMA leitura de `alunos` (docs/33), em vez da
  /// leitura separada, já filtrada a REPOSICAO, que `toResponse` usa.
  private toResponseComAlunos(aula: AulaComAlunosDetalhados): AulaResponseDto {
    return {
      ...this.camposComuns(aula),
      totalReposicoes: aula.alunos.filter((a) => a.tipo === AulaAlunoTipo.REPOSICAO).length,
      alunosNomes: aula.alunos.map((a) => a.aluno.nome),
    };
  }

  private camposComuns(
    aula: Omit<AulaComRelacoes, 'alunos'> | Omit<AulaComAlunosDetalhados, 'alunos'>,
  ): Omit<AulaResponseDto, 'totalReposicoes' | 'alunosNomes'> {
    return {
      id: aula.id,
      turmaId: aula.turmaId,
      turmaNome: aula.turma.nome,
      modalidadeId: aula.turma.modalidadeId,
      modalidadeNome: aula.turma.modalidade.nome,
      recorrenciaId: aula.recorrenciaId,
      data: aula.data,
      horaInicio: aula.horaInicio,
      duracaoMinutos: aula.duracaoMinutos,
      professorId: aula.professorId,
      professorNome: aula.professor.nome,
      capacidadeMaxima: aula.capacidadeMaxima,
      status: aula.status,
      motivoCancelamento: aula.motivoCancelamento,
      totalAlunos: aula._count.alunos,
      local: aula.turma.local,
      createdAt: aula.createdAt,
    };
  }
}
