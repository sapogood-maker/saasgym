import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction, LancamentoOrigem, Prisma } from '@prisma/client';
import { CreateLancamentoDto } from './dto/create-lancamento.dto';
import { UpdateLancamentoDto } from './dto/update-lancamento.dto';
import { ListLancamentosQueryDto } from './dto/list-lancamentos-query.dto';
import { ResumoLancamentosQueryDto } from './dto/resumo-lancamentos-query.dto';
import {
  LancamentoResponseDto,
  PaginatedLancamentosResponseDto,
} from './dto/lancamento-response.dto';
import { ResumoLancamentosResponseDto } from './dto/resumo-lancamentos-response.dto';
import { TenantContextService } from '../../../common/context/tenant-context.service';
import { RequestMetadata } from '../../../common/utils/request-metadata';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuditService } from '../../audit/audit.service';
import { intervaloDoMes } from '../financeiro.util';

/// Projeção de leitura — nome do aluno e vencimento da Mensalidade de
/// origem, só preenchidos quando `origem = MENSALIDADE` (pra navegar da
/// linha do Caixa até a competência correspondente em Mensalidades, sem
/// precisar de uma tela de Detalhe própria pra Lancamento).
const lancamentoInclude = {
  mensalidade: { select: { dataVencimento: true, aluno: { select: { nome: true } } } },
} satisfies Prisma.LancamentoInclude;

type LancamentoComRelacoes = Prisma.LancamentoGetPayload<{ include: typeof lancamentoInclude }>;

/// Receita/despesa manual — independente de Mensalidade (docs/17-modulo-3-
/// financeiro-analise.md, item 4). `origem = MENSALIDADE` é gerado pelo
/// sistema (MensalidadesService.marcarPaga) e não pode ser editado/
/// removido por aqui — reverter um pagamento é cancelar a Mensalidade,
/// não mexer no lançamento gerado.
@Injectable()
export class LancamentosService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async create(
    dto: CreateLancamentoDto,
    meta: RequestMetadata = {},
  ): Promise<LancamentoResponseDto> {
    const academiaId = this.tenantContext.getAcademiaId() as string;
    const userId = this.tenantContext.getUserId() as string;

    const lancamento = await this.prisma.forTenant().lancamento.create({
      data: {
        tipo: dto.tipo,
        origem: LancamentoOrigem.MANUAL,
        descricao: dto.descricao,
        categoria: dto.categoria,
        valor: dto.valor,
        data: new Date(dto.data),
        formaPagamento: dto.formaPagamento,
        createdByUserId: userId,
      } as Prisma.LancamentoUncheckedCreateInput,
      include: lancamentoInclude,
    });

    await this.auditService.record({
      action: AuditAction.LANCAMENTO_CREATED,
      academiaId,
      userId,
      metadata: { lancamentoId: lancamento.id, tipo: dto.tipo, valor: dto.valor },
      ...meta,
    });

    return this.toResponse(lancamento);
  }

  async list(query: ListLancamentosQueryDto): Promise<PaginatedLancamentosResponseDto> {
    const where: Prisma.LancamentoWhereInput = { deletedAt: null };
    if (query.tipo) {
      where.tipo = query.tipo;
    }
    if (query.mes && query.ano) {
      const { inicio, fim } = intervaloDoMes(query.mes, query.ano);
      where.data = { gte: inicio, lt: fim };
    } else if (query.dataInicio || query.dataFim) {
      where.data = {
        ...(query.dataInicio && { gte: new Date(query.dataInicio) }),
        ...(query.dataFim && { lte: new Date(query.dataFim) }),
      };
    }

    const [items, total] = await Promise.all([
      this.prisma.forTenant().lancamento.findMany({
        where,
        include: lancamentoInclude,
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: { data: 'desc' },
      }),
      this.prisma.forTenant().lancamento.count({ where }),
    ]);

    return {
      items: items.map((l) => this.toResponse(l)),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  /// Resumo financeiro do período — soma real no banco (groupBy), não
  /// client-side (a lista é paginada, somar só a página atual daria conta
  /// errada). Sem mes/ano, usa o mês corrente — mesmo padrão de
  /// `MensalidadesService.gerar`.
  async resumo(query: ResumoLancamentosQueryDto): Promise<ResumoLancamentosResponseDto> {
    const agora = new Date();
    const mes = query.mes ?? agora.getUTCMonth() + 1;
    const ano = query.ano ?? agora.getUTCFullYear();
    const { inicio, fim } = intervaloDoMes(mes, ano);

    const grupos = await this.prisma.forTenant().lancamento.groupBy({
      by: ['tipo'],
      where: { deletedAt: null, data: { gte: inicio, lt: fim } },
      _sum: { valor: true },
      _count: true,
    });

    const receitas = grupos.find((g) => g.tipo === 'RECEITA');
    const despesas = grupos.find((g) => g.tipo === 'DESPESA');
    const totalReceitas = Number(receitas?._sum.valor ?? 0);
    const totalDespesas = Number(despesas?._sum.valor ?? 0);

    return {
      totalReceitas,
      totalDespesas,
      saldo: Math.round((totalReceitas - totalDespesas) * 100) / 100,
      quantidadeReceitas: receitas?._count ?? 0,
      quantidadeDespesas: despesas?._count ?? 0,
    };
  }

  async findOne(id: string): Promise<LancamentoResponseDto> {
    return this.toResponse(await this.findOrThrow(id));
  }

  async update(
    id: string,
    dto: UpdateLancamentoDto,
    meta: RequestMetadata = {},
  ): Promise<LancamentoResponseDto> {
    const atual = await this.findOrThrow(id);
    this.garantirNaoGeradoPorMensalidade(atual);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const lancamento = await this.prisma.forTenant().lancamento.update({
      where: { id },
      data: {
        ...(dto.tipo && { tipo: dto.tipo }),
        ...(dto.descricao && { descricao: dto.descricao }),
        ...(dto.categoria !== undefined && { categoria: dto.categoria }),
        ...(dto.valor !== undefined && { valor: dto.valor }),
        ...(dto.data && { data: new Date(dto.data) }),
        ...(dto.formaPagamento !== undefined && { formaPagamento: dto.formaPagamento }),
      },
      include: lancamentoInclude,
    });

    await this.auditService.record({
      action: AuditAction.LANCAMENTO_UPDATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { lancamentoId: id, camposAlterados: Object.keys(dto) },
      ...meta,
    });

    return this.toResponse(lancamento);
  }

  async remove(id: string, meta: RequestMetadata = {}): Promise<void> {
    const atual = await this.findOrThrow(id);
    this.garantirNaoGeradoPorMensalidade(atual);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    await this.prisma
      .forTenant()
      .lancamento.update({ where: { id }, data: { deletedAt: new Date() } });

    await this.auditService.record({
      action: AuditAction.LANCAMENTO_DELETED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { lancamentoId: id },
      ...meta,
    });
  }

  private garantirNaoGeradoPorMensalidade(lancamento: LancamentoComRelacoes): void {
    if (lancamento.origem === LancamentoOrigem.MENSALIDADE) {
      throw new BadRequestException(
        'Lançamento gerado automaticamente pelo pagamento de uma mensalidade — não pode ser editado ou removido diretamente',
      );
    }
  }

  private async findOrThrow(id: string): Promise<LancamentoComRelacoes> {
    const lancamento = await this.prisma
      .forTenant()
      .lancamento.findFirst({ where: { id, deletedAt: null }, include: lancamentoInclude });
    if (!lancamento) {
      throw new NotFoundException('Lançamento não encontrado');
    }
    return lancamento;
  }

  private toResponse(lancamento: LancamentoComRelacoes): LancamentoResponseDto {
    return {
      id: lancamento.id,
      tipo: lancamento.tipo,
      origem: lancamento.origem,
      descricao: lancamento.descricao,
      categoria: lancamento.categoria,
      valor: Number(lancamento.valor),
      data: lancamento.data,
      formaPagamento: lancamento.formaPagamento,
      mensalidadeId: lancamento.mensalidadeId,
      alunoNome: lancamento.mensalidade?.aluno.nome ?? null,
      mensalidadeDataVencimento: lancamento.mensalidade?.dataVencimento ?? null,
      createdAt: lancamento.createdAt,
    };
  }
}
