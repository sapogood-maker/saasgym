import { BadRequestException, ConflictException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { AulaAlunoTipo, AulaStatus, AuditAction, Prisma, Role, SolicitacaoReposicaoStatus } from '@prisma/client';
import { CreateSolicitacaoReposicaoDto } from './dto/create-solicitacao-reposicao.dto';
import { AprovarSolicitacaoReposicaoDto } from './dto/aprovar-solicitacao-reposicao.dto';
import { RejeitarSolicitacaoReposicaoDto } from './dto/rejeitar-solicitacao-reposicao.dto';
import { ListSolicitacoesReposicaoQueryDto } from './dto/list-solicitacoes-reposicao-query.dto';
import {
  PaginatedSolicitacoesReposicaoResponseDto,
  SolicitacaoReposicaoResponseDto,
} from './dto/solicitacao-reposicao-response.dto';
import { TenantContextService } from '../../../common/context/tenant-context.service';
import { RequestMetadata } from '../../../common/utils/request-metadata';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuditService } from '../../audit/audit.service';
import {
  NOTIFICATION_PROVIDER,
  NotificationProvider,
} from '../../../notifications/notification-provider.interface';

const solicitacaoInclude = {
  aluno: { select: { nome: true } },
  aulaAlunoOrigem: { select: { aula: { select: { data: true, turma: { select: { nome: true } } } } } },
  aulaDestino: { select: { data: true, turma: { select: { nome: true } } } },
  createdByUser: { select: { nome: true } },
  decidedByUser: { select: { nome: true } },
} satisfies Prisma.SolicitacaoReposicaoInclude;

type SolicitacaoComRelacoes = Prisma.SolicitacaoReposicaoGetPayload<{
  include: typeof solicitacaoInclude;
}>;

/// Sprint 6 (Agenda Avançada) — **invariantes explícitas antes de qualquer
/// código (docs/21)**:
///
/// 1. A solicitação nasce só com a aula de origem perdida — `aulaDestinoId`
///    fica nulo até a aprovação (decisão 3).
/// 2. Origem só pode ser uma aula já realizada, com falta (`AUSENTE`/
///    `JUSTIFICADA`) ou cancelada — nunca futura, nunca com presença
///    (decisão 2).
/// 3. Aprovar é o único caminho que cria um `AulaAluno(tipo=REPOSICAO)` —
///    sem atalho direto (decisão 5). A capacidade da aula de destino é
///    recontada dentro de uma transação, no momento da aprovação, nunca
///    na criação da solicitação.
/// 4. Qualquer `ACADEMIA_ADMIN`/`RECEPCIONISTA` pode aprovar ou rejeitar,
///    inclusive quem criou — sem papel de "supervisor" (decisão 4).
@Injectable()
export class SolicitacoesReposicaoService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
    @Inject(NOTIFICATION_PROVIDER) private readonly notificationProvider: NotificationProvider,
  ) {}

  async criar(
    dto: CreateSolicitacaoReposicaoDto,
    meta: RequestMetadata = {},
  ): Promise<SolicitacaoReposicaoResponseDto> {
    const academiaId = this.tenantContext.getAcademiaId() as string;
    const userId = this.tenantContext.getUserId() as string;

    const origem = await this.garantirOrigemElegivel(dto.aulaAlunoOrigemId);
    await this.garantirSemSolicitacaoAtiva(dto.aulaAlunoOrigemId);

    const solicitacao = await this.prisma.forTenant().solicitacaoReposicao.create({
      data: {
        alunoId: origem.alunoId,
        aulaAlunoOrigemId: origem.id,
        observacoes: dto.observacoes,
        createdByUserId: userId,
      } as Prisma.SolicitacaoReposicaoUncheckedCreateInput,
      include: solicitacaoInclude,
    });

    await this.auditService.record({
      action: AuditAction.SOLICITACAO_REPOSICAO_CRIADA,
      academiaId,
      userId,
      metadata: { solicitacaoId: solicitacao.id, alunoId: origem.alunoId, aulaAlunoOrigemId: origem.id },
      ...meta,
    });

    await this.notificarNovaSolicitacao(solicitacao, userId);

    return this.toResponse(solicitacao);
  }

  async list(query: ListSolicitacoesReposicaoQueryDto): Promise<PaginatedSolicitacoesReposicaoResponseDto> {
    const where: Prisma.SolicitacaoReposicaoWhereInput = {};
    if (query.status) {
      where.status = query.status;
    }
    if (query.alunoId) {
      where.alunoId = query.alunoId;
    }

    const [items, total] = await Promise.all([
      this.prisma.forTenant().solicitacaoReposicao.findMany({
        where,
        include: solicitacaoInclude,
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.forTenant().solicitacaoReposicao.count({ where }),
    ]);

    return {
      items: items.map((solicitacao) => this.toResponse(solicitacao)),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  async aprovar(
    id: string,
    dto: AprovarSolicitacaoReposicaoDto,
    meta: RequestMetadata = {},
  ): Promise<SolicitacaoReposicaoResponseDto> {
    const academiaId = this.tenantContext.getAcademiaId() as string;
    const userId = this.tenantContext.getUserId() as string;

    const atual = await this.findOrThrow(id);
    if (atual.status !== SolicitacaoReposicaoStatus.PENDENTE) {
      throw new BadRequestException('Só é possível aprovar uma solicitação PENDENTE');
    }

    const destino = await this.garantirDestinoValido(dto.aulaDestinoId);

    const jaVinculado = await this.prisma.forTenant().aulaAluno.findFirst({
      where: { aulaId: destino.id, alunoId: atual.alunoId, deletedAt: null },
    });
    if (jaVinculado) {
      throw new BadRequestException('O aluno já está vinculado a esta aula');
    }

    // $transaction: recontagem de capacidade + criação do AulaAluno +
    // atualização da solicitação precisam ser atômicas (docs/21, decisão
    // 3/5) — mesmo padrão já usado em AulasService.gerar/
    // AdminAcademiaService.updateStatus. tx bypassa forTenant(), academiaId
    // explícito nas escritas.
    const resultado = await this.prisma.$transaction(async (tx) => {
      if (destino.capacidadeMaxima !== null) {
        const totalAtual = await tx.aulaAluno.count({
          where: { aulaId: destino.id, deletedAt: null },
        });
        if (totalAtual >= destino.capacidadeMaxima) {
          throw new ConflictException('A aula de destino atingiu a capacidade máxima de alunos');
        }
      }

      const aulaAlunoReposicao = await tx.aulaAluno.create({
        data: {
          academiaId,
          aulaId: destino.id,
          alunoId: atual.alunoId,
          tipo: AulaAlunoTipo.REPOSICAO,
          reposicaoDeAulaAlunoId: atual.aulaAlunoOrigemId,
        } as Prisma.AulaAlunoUncheckedCreateInput,
      });

      const atualizada = await tx.solicitacaoReposicao.update({
        where: { id },
        data: {
          status: SolicitacaoReposicaoStatus.APROVADA,
          aulaDestinoId: destino.id,
          aulaAlunoReposicaoId: aulaAlunoReposicao.id,
          decidedByUserId: userId,
          decidedAt: new Date(),
        },
        include: solicitacaoInclude,
      });

      return { atualizada, aulaAlunoReposicao };
    });

    await this.auditService.record({
      action: AuditAction.SOLICITACAO_REPOSICAO_APROVADA,
      academiaId,
      userId,
      metadata: { solicitacaoId: id, aulaDestinoId: destino.id },
      ...meta,
    });
    await this.auditService.record({
      action: AuditAction.AULA_ALUNO_REPOSICAO_CRIADA,
      academiaId,
      userId,
      metadata: {
        aulaAlunoId: resultado.aulaAlunoReposicao.id,
        aulaId: destino.id,
        alunoId: atual.alunoId,
        reposicaoDeAulaAlunoId: atual.aulaAlunoOrigemId,
      },
      ...meta,
    });

    await this.notificarDecisao(resultado.atualizada);

    return this.toResponse(resultado.atualizada);
  }

  async rejeitar(
    id: string,
    dto: RejeitarSolicitacaoReposicaoDto,
    meta: RequestMetadata = {},
  ): Promise<SolicitacaoReposicaoResponseDto> {
    const academiaId = this.tenantContext.getAcademiaId() as string;
    const userId = this.tenantContext.getUserId() as string;

    const atual = await this.findOrThrow(id);
    if (atual.status !== SolicitacaoReposicaoStatus.PENDENTE) {
      throw new BadRequestException('Só é possível rejeitar uma solicitação PENDENTE');
    }

    const rejeitada = await this.prisma.forTenant().solicitacaoReposicao.update({
      where: { id },
      data: {
        status: SolicitacaoReposicaoStatus.REJEITADA,
        motivoRejeicao: dto.motivoRejeicao,
        decidedByUserId: userId,
        decidedAt: new Date(),
      },
      include: solicitacaoInclude,
    });

    await this.auditService.record({
      action: AuditAction.SOLICITACAO_REPOSICAO_REJEITADA,
      academiaId,
      userId,
      metadata: { solicitacaoId: id, motivo: dto.motivoRejeicao },
      ...meta,
    });

    await this.notificarDecisao(rejeitada);

    return this.toResponse(rejeitada);
  }

  /// Origem elegível (docs/21, decisão 2): aula já realizada (`data < hoje`,
  /// mesma comparação de data-only usada em toda a Agenda) **e** (aula
  /// cancelada OU presença marcada como falta). Nunca aula futura, nunca
  /// aula com presença.
  private async garantirOrigemElegivel(
    aulaAlunoOrigemId: string,
  ): Promise<{ id: string; alunoId: string }> {
    const origem = await this.prisma.forTenant().aulaAluno.findFirst({
      where: { id: aulaAlunoOrigemId, deletedAt: null },
      include: { aula: { select: { data: true, status: true } } },
    });
    if (!origem) {
      throw new NotFoundException('Aula/aluno de origem não encontrado');
    }

    const hoje = new Date();
    const inicioHoje = new Date(Date.UTC(hoje.getUTCFullYear(), hoje.getUTCMonth(), hoje.getUTCDate()));
    if (origem.aula.data.getTime() >= inicioHoje.getTime()) {
      throw new BadRequestException('Só é possível solicitar reposição de uma aula já realizada');
    }

    const cancelada = origem.aula.status === AulaStatus.CANCELADA;
    const teveFalta = origem.presenca === 'AUSENTE' || origem.presenca === 'JUSTIFICADA';
    if (!cancelada && !teveFalta) {
      throw new BadRequestException(
        'Só é possível solicitar reposição de uma aula com falta ou cancelada',
      );
    }

    return { id: origem.id, alunoId: origem.alunoId };
  }

  /// No máximo uma solicitação PENDENTE/APROVADA ativa por origem —
  /// validado no service, nunca uma `@@unique` de banco na FK sozinha
  /// (docs/21, decisão 6 — mesma lição já aprendida com o bug real de
  /// `TurmaAluno` no Módulo 4 MS5).
  private async garantirSemSolicitacaoAtiva(aulaAlunoOrigemId: string): Promise<void> {
    const ativa = await this.prisma.forTenant().solicitacaoReposicao.findFirst({
      where: {
        aulaAlunoOrigemId,
        status: { in: [SolicitacaoReposicaoStatus.PENDENTE, SolicitacaoReposicaoStatus.APROVADA] },
      },
    });
    if (ativa) {
      throw new ConflictException('Já existe uma solicitação de reposição ativa para esta aula');
    }
  }

  private async garantirDestinoValido(
    aulaDestinoId: string,
  ): Promise<{ id: string; capacidadeMaxima: number | null }> {
    const destino = await this.prisma.forTenant().aula.findFirst({
      where: { id: aulaDestinoId, deletedAt: null },
    });
    if (!destino) {
      throw new NotFoundException('Aula de destino não encontrada');
    }
    if (destino.status !== AulaStatus.AGENDADA) {
      throw new BadRequestException('A aula de destino precisa estar agendada (não cancelada)');
    }
    const hoje = new Date();
    const inicioHoje = new Date(Date.UTC(hoje.getUTCFullYear(), hoje.getUTCMonth(), hoje.getUTCDate()));
    if (destino.data.getTime() < inicioHoje.getTime()) {
      throw new BadRequestException('A aula de destino precisa ser uma aula futura');
    }
    return { id: destino.id, capacidadeMaxima: destino.capacidadeMaxima };
  }

  private async findOrThrow(id: string): Promise<SolicitacaoComRelacoes> {
    const solicitacao = await this.prisma
      .forTenant()
      .solicitacaoReposicao.findFirst({ where: { id }, include: solicitacaoInclude });
    if (!solicitacao) {
      throw new NotFoundException('Solicitação de reposição não encontrada');
    }
    return solicitacao;
  }

  /// Ao criar (docs/21, decisão 9): avisa os demais ACADEMIA_ADMIN/
  /// RECEPCIONISTA da academia — nunca quem acabou de criar (já sabe).
  private async notificarNovaSolicitacao(
    solicitacao: SolicitacaoComRelacoes,
    criadoPorUserId: string,
  ): Promise<void> {
    const destinatarios = await this.prisma.forTenant().user.findMany({
      where: {
        role: { in: [Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA] },
        id: { not: criadoPorUserId },
        status: 'ATIVO',
      },
      select: { id: true },
    });

    const mensagem = `${solicitacao.aluno.nome} solicitou reposição da aula de ${this.formatarData(solicitacao.aulaAlunoOrigem.aula.data)} (${solicitacao.aulaAlunoOrigem.aula.turma.nome}).`;

    await Promise.all(
      destinatarios.map((destinatario) =>
        this.notificationProvider.notify({
          userId: destinatario.id,
          titulo: 'Nova solicitação de reposição',
          mensagem,
        }),
      ),
    );
  }

  /// Ao decidir (docs/21, decisão 9): avisa quem criou a solicitação — é
  /// quem precisa repassar a resposta pro aluno.
  private async notificarDecisao(solicitacao: SolicitacaoComRelacoes): Promise<void> {
    if (solicitacao.status === SolicitacaoReposicaoStatus.APROVADA) {
      await this.notificationProvider.notify({
        userId: solicitacao.createdByUserId,
        titulo: 'Solicitação de reposição aprovada',
        mensagem: `A reposição de ${solicitacao.aluno.nome} foi aprovada para ${this.formatarData(solicitacao.aulaDestino!.data)} (${solicitacao.aulaDestino!.turma.nome}).`,
      });
    } else if (solicitacao.status === SolicitacaoReposicaoStatus.REJEITADA) {
      const sufixoMotivo = solicitacao.motivoRejeicao ? ` Motivo: ${solicitacao.motivoRejeicao}` : '';
      await this.notificationProvider.notify({
        userId: solicitacao.createdByUserId,
        titulo: 'Solicitação de reposição rejeitada',
        mensagem: `A reposição de ${solicitacao.aluno.nome} foi rejeitada.${sufixoMotivo}`,
      });
    }
  }

  private formatarData(data: Date): string {
    return data.toISOString().slice(0, 10);
  }

  private toResponse(solicitacao: SolicitacaoComRelacoes): SolicitacaoReposicaoResponseDto {
    return {
      id: solicitacao.id,
      alunoId: solicitacao.alunoId,
      alunoNome: solicitacao.aluno.nome,
      aulaAlunoOrigemId: solicitacao.aulaAlunoOrigemId,
      aulaOrigemData: solicitacao.aulaAlunoOrigem.aula.data,
      aulaOrigemTurmaNome: solicitacao.aulaAlunoOrigem.aula.turma.nome,
      aulaDestinoId: solicitacao.aulaDestinoId,
      aulaDestinoData: solicitacao.aulaDestino?.data ?? null,
      aulaDestinoTurmaNome: solicitacao.aulaDestino?.turma.nome ?? null,
      status: solicitacao.status,
      observacoes: solicitacao.observacoes,
      motivoRejeicao: solicitacao.motivoRejeicao,
      createdByUserId: solicitacao.createdByUserId,
      createdByUserNome: solicitacao.createdByUser.nome,
      decidedByUserId: solicitacao.decidedByUserId,
      decidedByUserNome: solicitacao.decidedByUser?.nome ?? null,
      decidedAt: solicitacao.decidedAt,
      createdAt: solicitacao.createdAt,
    };
  }
}
