import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction, MatriculaStatus, MensalidadeStatus, Prisma } from '@prisma/client';
import { GerarMensalidadesDto } from './dto/gerar-mensalidades.dto';
import { ListMensalidadesQueryDto } from './dto/list-mensalidades-query.dto';
import { UpdateMensalidadeDto } from './dto/update-mensalidade.dto';
import { MarcarPagaMensalidadeDto } from './dto/marcar-paga-mensalidade.dto';
import { CancelarMensalidadeDto } from './dto/cancelar-mensalidade.dto';
import {
  GerarMensalidadesResponseDto,
  MensalidadeResponseDto,
  PaginatedMensalidadesResponseDto,
} from './dto/mensalidade-response.dto';
import { MensalidadeAlertaResponseDto } from './dto/mensalidade-alerta-response.dto';
import { dataVencimentoNoMes, valorFinal } from './mensalidades.util';
import { intervaloDoMes } from '../financeiro.util';
import { TenantContextService } from '../../../common/context/tenant-context.service';
import { RequestMetadata } from '../../../common/utils/request-metadata';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuditService } from '../../audit/audit.service';

/// Projeção de leitura pro frontend (nome do aluno, forma de pagamento do
/// Lancamento gerado) — mesmo motivo/padrão de `matriculaInclude` em
/// MatriculasService.
const mensalidadeInclude = {
  aluno: { select: { nome: true } },
  lancamento: { select: { formaPagamento: true } },
} satisfies Prisma.MensalidadeInclude;

type MensalidadeComRelacoes = Prisma.MensalidadeGetPayload<{ include: typeof mensalidadeInclude }>;

/// Cap da lista de alertas do Dashboard (docs/22, decisão 4) — lista curta
/// e acionável, não uma paginação completa (essa já existe na tela de
/// Mensalidades).
const MENSALIDADES_ALERTA_LIMITE = 10;

/// Cobrança mensal derivada de Matricula. Gerada sob demanda (`gerar`, sem
/// scheduler — docs/17-modulo-3-financeiro-analise.md, item 2), nunca
/// duplicada pro mesmo (matriculaId, mês/ano). Ciclo de vida simples:
/// PENDENTE -> PAGA (marcarPaga, cria Lancamento) | PENDENTE -> CANCELADA
/// (cancelar). "Atrasada" nunca é armazenado, é sempre calculado em
/// `toResponse` (item 1 do doc acima).
@Injectable()
export class MensalidadesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  /// Idempotente: rodar duas vezes pro mesmo mês/ano não duplica — a
  /// própria constraint `@@unique([matriculaId, dataVencimento])` do banco
  /// é quem decide "já existe" (P2002 = pula), nunca uma checagem de
  /// aplicação. Antes disso havia um `findFirst` prévio filtrando
  /// `deletedAt: null`, que ignorava mensalidades removidas por engano
  /// (`remove()`) e não era atômico com o `create` — as duas causas reais
  /// da duplicidade em produção corrigida na migration
  /// 20260717150000_consolida_mensalidades_duplicadas_indice_completo (ver
  /// docs/31). Confiar só na constraint elimina ambas de uma vez: soft-delete
  /// não libera a chave (mesma regra de negócio do índice completo) e dois
  /// `create` concorrentes pro mesmo par nunca coexistem, porque o Postgres
  /// serializa o conflito — só um vence, o outro recebe P2002.
  ///
  /// Só considera Matriculas ATIVAS cuja vigência (dataInicio..dataFim)
  /// cobre o mês alvo (evita gerar cobrança pra um contrato já vencido que
  /// continua "ATIVA" no banco só por falta de renovação/scheduler).
  async gerar(
    dto: GerarMensalidadesDto,
    meta: RequestMetadata = {},
  ): Promise<GerarMensalidadesResponseDto> {
    const agora = new Date();
    const mes = dto.mes ?? agora.getUTCMonth() + 1;
    const ano = dto.ano ?? agora.getUTCFullYear();
    const { inicio, fim } = intervaloDoMes(mes, ano);

    const academiaId = this.tenantContext.getAcademiaId() as string;
    const userId = this.tenantContext.getUserId() as string;

    const matriculas = await this.prisma.forTenant().matricula.findMany({
      where: {
        status: MatriculaStatus.ATIVA,
        deletedAt: null,
        dataInicio: { lt: fim },
        dataFim: { gte: inicio },
      },
      include: { aluno: { select: { nome: true } } },
    });

    const criadas: MensalidadeComRelacoes[] = [];
    let totalPuladas = 0;

    for (const matricula of matriculas) {
      try {
        const mensalidade = await this.prisma.forTenant().mensalidade.create({
          data: {
            matriculaId: matricula.id,
            alunoId: matricula.alunoId,
            valor: matricula.valor,
            dataVencimento: dataVencimentoNoMes(mes, ano, matricula.diaVencimento),
            createdByUserId: userId,
          } as Prisma.MensalidadeUncheckedCreateInput,
          include: mensalidadeInclude,
        });
        criadas.push(mensalidade);
      } catch (e) {
        if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
          totalPuladas++;
          continue;
        }
        throw e;
      }
    }

    await this.auditService.record({
      action: AuditAction.MENSALIDADE_GERADA,
      academiaId,
      userId,
      metadata: { mes, ano, totalGeradas: criadas.length, totalPuladas },
      ...meta,
    });

    return {
      criadas: criadas.map((m) => this.toResponse(m)),
      totalPuladas,
    };
  }

  async list(query: ListMensalidadesQueryDto): Promise<PaginatedMensalidadesResponseDto> {
    const where: Prisma.MensalidadeWhereInput = { deletedAt: null };
    if (query.matriculaId) {
      where.matriculaId = query.matriculaId;
    }
    if (query.alunoId) {
      where.alunoId = query.alunoId;
    }
    if (query.status) {
      where.status = query.status;
    }
    if (query.mes && query.ano) {
      const { inicio, fim } = intervaloDoMes(query.mes, query.ano);
      where.dataVencimento = { gte: inicio, lt: fim };
    }
    if (query.search) {
      where.aluno = { nome: { contains: query.search, mode: 'insensitive' } };
    }

    const [items, total] = await Promise.all([
      this.prisma.forTenant().mensalidade.findMany({
        where,
        include: mensalidadeInclude,
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: { dataVencimento: 'desc' },
      }),
      this.prisma.forTenant().mensalidade.count({ where }),
    ]);

    return {
      items: items.map((m) => this.toResponse(m)),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  async findOne(id: string): Promise<MensalidadeResponseDto> {
    return this.toResponse(await this.findOrThrow(id));
  }

  async update(
    id: string,
    dto: UpdateMensalidadeDto,
    meta: RequestMetadata = {},
  ): Promise<MensalidadeResponseDto> {
    const atual = await this.findOrThrow(id);
    if (atual.status !== MensalidadeStatus.PENDENTE) {
      throw new BadRequestException('Só é possível editar uma mensalidade PENDENTE');
    }
    const academiaId = this.tenantContext.getAcademiaId() as string;

    // Validação cruzada (docs/30, item "fortemente recomendado"): desconto e
    // multa são validados isoladamente pelo DTO (>= 0 cada), mas nada
    // impedia um desconto maior que valor + multa, resultando num
    // valorFinal negativo — um estado financeiro sem sentido de negócio.
    const descontoFinal = dto.desconto ?? Number(atual.desconto);
    const multaFinal = dto.multa ?? Number(atual.multa);
    if (valorFinal(Number(atual.valor), descontoFinal, multaFinal) < 0) {
      throw new BadRequestException(
        'O desconto não pode deixar o valor final da mensalidade negativo',
      );
    }

    const mensalidade = await this.prisma.forTenant().mensalidade.update({
      where: { id },
      data: {
        ...(dto.desconto !== undefined && { desconto: dto.desconto }),
        ...(dto.multa !== undefined && { multa: dto.multa }),
        ...(dto.dataVencimento && { dataVencimento: new Date(dto.dataVencimento) }),
      },
    });

    await this.auditService.record({
      action: AuditAction.MENSALIDADE_UPDATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { mensalidadeId: id, camposAlterados: Object.keys(dto) },
      ...meta,
    });

    return this.toResponse({ ...mensalidade, aluno: atual.aluno, lancamento: atual.lancamento });
  }

  async marcarPaga(
    id: string,
    dto: MarcarPagaMensalidadeDto,
    meta: RequestMetadata = {},
  ): Promise<MensalidadeResponseDto> {
    const atual = await this.findOrThrow(id);
    if (atual.status !== MensalidadeStatus.PENDENTE) {
      throw new BadRequestException('Só é possível marcar como paga uma mensalidade PENDENTE');
    }
    const academiaId = this.tenantContext.getAcademiaId() as string;
    const userId = this.tenantContext.getUserId() as string;
    const dataPagamento = dto.dataPagamento ? new Date(dto.dataPagamento) : new Date();
    const valorFinalCalc = valorFinal(
      Number(atual.valor),
      Number(atual.desconto),
      Number(atual.multa),
    );

    // Transação com o client base (não forTenant()) — mesmo padrão já usado
    // em MatriculasService.renovar: dentro de uma transação interativa, o
    // where/data inclui academiaId explícito porque a extensão de tenant
    // não intercepta `tx`.
    const mensalidade = await this.prisma.$transaction(async (tx) => {
      const atualizada = await tx.mensalidade.update({
        where: { id, academiaId },
        data: { status: MensalidadeStatus.PAGA, dataPagamento },
      });

      await tx.lancamento.create({
        data: {
          academiaId,
          tipo: 'RECEITA',
          origem: 'MENSALIDADE',
          descricao: `Mensalidade — ${atual.aluno.nome}`,
          valor: valorFinalCalc,
          data: dataPagamento,
          formaPagamento: dto.formaPagamento,
          mensalidadeId: id,
          createdByUserId: userId,
        },
      });

      return atualizada;
    });

    await this.auditService.record({
      action: AuditAction.MENSALIDADE_PAGA,
      academiaId,
      userId,
      metadata: {
        mensalidadeId: id,
        valorFinal: valorFinalCalc,
        formaPagamento: dto.formaPagamento,
      },
      ...meta,
    });

    return this.toResponse({
      ...mensalidade,
      aluno: atual.aluno,
      lancamento: { formaPagamento: dto.formaPagamento },
    });
  }

  async cancelar(
    id: string,
    dto: CancelarMensalidadeDto,
    meta: RequestMetadata = {},
  ): Promise<MensalidadeResponseDto> {
    const atual = await this.findOrThrow(id);
    if (atual.status !== MensalidadeStatus.PENDENTE) {
      throw new BadRequestException('Só é possível cancelar uma mensalidade PENDENTE');
    }
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const mensalidade = await this.prisma.forTenant().mensalidade.update({
      where: { id },
      data: { status: MensalidadeStatus.CANCELADA, motivoCancelamento: dto.motivo },
    });

    await this.auditService.record({
      action: AuditAction.MENSALIDADE_CANCELADA,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { mensalidadeId: id, motivo: dto.motivo },
      ...meta,
    });

    return this.toResponse({ ...mensalidade, aluno: atual.aluno, lancamento: null });
  }

  /// Reservado a correção de erro de cadastro (mensalidade gerada por
  /// engano) — bloqueado quando `status = PAGA` pra nunca órfão o
  /// Lancamento já gerado pelo pagamento (docs/17, item 4). Reverter um
  /// pagamento de verdade é um caso de estorno, fora do escopo do MVP.
  async remove(id: string, meta: RequestMetadata = {}): Promise<void> {
    const atual = await this.findOrThrow(id);
    if (atual.status === MensalidadeStatus.PAGA) {
      throw new BadRequestException(
        'Não é possível remover uma mensalidade paga — o lançamento gerado pelo pagamento ficaria órfão',
      );
    }
    const academiaId = this.tenantContext.getAcademiaId() as string;

    await this.prisma
      .forTenant()
      .mensalidade.update({ where: { id }, data: { deletedAt: new Date() } });

    await this.auditService.record({
      action: AuditAction.MENSALIDADE_DELETED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { mensalidadeId: id },
      ...meta,
    });
  }

  /// Receita prevista do mês — soma de `Matricula.valor` das ATIVA cuja
  /// vigência cobre o período (mesma query de elegibilidade de `gerar`,
  /// sem criar registro nenhum). Funciona mesmo antes de "Gerar
  /// mensalidades do mês" ter rodado — é o número de planejamento, não o
  /// que já foi de fato cobrado (docs/17, seção "MS5").
  async receitaPrevista(
    mes: number,
    ano: number,
  ): Promise<{ valor: number; quantidadeMatriculas: number }> {
    const { inicio, fim } = intervaloDoMes(mes, ano);

    const matriculas = await this.prisma.forTenant().matricula.findMany({
      where: {
        status: MatriculaStatus.ATIVA,
        deletedAt: null,
        dataInicio: { lt: fim },
        dataFim: { gte: inicio },
      },
      select: { valor: true },
    });

    const valor = matriculas.reduce((soma, m) => soma + Number(m.valor), 0);
    return { valor: Math.round(valor * 100) / 100, quantidadeMatriculas: matriculas.length };
  }

  /// Inadimplência — sempre tempo real (todas as PENDENTE vencidas até
  /// hoje, de qualquer mês), não escopada a uma competência: uma
  /// mensalidade de março ainda não paga em julho continua inadimplente
  /// hoje, não é um dado histórico de março (docs/17, seção "MS5",
  /// decisão confirmada pelo dono do produto).
  async inadimplencia(): Promise<{ valor: number; quantidade: number }> {
    const hoje = new Date();

    const mensalidades = await this.prisma.forTenant().mensalidade.findMany({
      where: { status: MensalidadeStatus.PENDENTE, dataVencimento: { lt: hoje }, deletedAt: null },
      select: { valor: true, desconto: true, multa: true },
    });

    const valor = mensalidades.reduce(
      (soma, m) => soma + valorFinal(Number(m.valor), Number(m.desconto), Number(m.multa)),
      0,
    );
    return { valor: Math.round(valor * 100) / 100, quantidade: mensalidades.length };
  }

  /// Alertas do Dashboard (docs/22, decisões 3/4/6) — mensalidades
  /// PENDENTE já vencidas ou que vencem dentro de `dias` a partir de hoje,
  /// numa única lista ordenada por `dataVencimento` ascendente: como
  /// vencidas têm data no passado e "a vencer" no futuro, essa ordenação
  /// já produz "vencidas primeiro, depois a vencer" sem precisar de dois
  /// grupos separados. Capada em `MENSALIDADES_ALERTA_LIMITE` — é um
  /// alerta acionável, não uma listagem completa.
  async proximosVencimentos(dias: number): Promise<MensalidadeAlertaResponseDto[]> {
    // `dataVencimento` é sempre meia-noite UTC do dia (`dataVencimentoNoMes`)
    // — truncar "hoje" pro dia em UTC, não a hora corrente, senão uma
    // mensalidade vencendo hoje mais tarde no dia ficaria de fora do `lte`.
    const agora = new Date();
    const hoje = new Date(
      Date.UTC(agora.getUTCFullYear(), agora.getUTCMonth(), agora.getUTCDate()),
    );
    const limite = new Date(hoje.getTime() + dias * 24 * 60 * 60 * 1000);

    const mensalidades = await this.prisma.forTenant().mensalidade.findMany({
      where: {
        status: MensalidadeStatus.PENDENTE,
        dataVencimento: { lte: limite },
        deletedAt: null,
      },
      include: mensalidadeInclude,
      orderBy: { dataVencimento: 'asc' },
      take: MENSALIDADES_ALERTA_LIMITE,
    });

    return mensalidades.map((m) => ({
      id: m.id,
      alunoId: m.alunoId,
      alunoNome: m.aluno.nome,
      valor: valorFinal(Number(m.valor), Number(m.desconto), Number(m.multa)),
      dataVencimento: m.dataVencimento,
      vencida: m.dataVencimento < hoje,
    }));
  }

  private async findOrThrow(id: string): Promise<MensalidadeComRelacoes> {
    const mensalidade = await this.prisma
      .forTenant()
      .mensalidade.findFirst({ where: { id, deletedAt: null }, include: mensalidadeInclude });
    if (!mensalidade) {
      throw new NotFoundException('Mensalidade não encontrada');
    }
    return mensalidade;
  }

  private toResponse(mensalidade: MensalidadeComRelacoes): MensalidadeResponseDto {
    const valor = Number(mensalidade.valor);
    const desconto = Number(mensalidade.desconto);
    const multa = Number(mensalidade.multa);

    return {
      id: mensalidade.id,
      matriculaId: mensalidade.matriculaId,
      alunoId: mensalidade.alunoId,
      alunoNome: mensalidade.aluno.nome,
      valor,
      desconto,
      multa,
      valorFinal: valorFinal(valor, desconto, multa),
      dataVencimento: mensalidade.dataVencimento,
      dataPagamento: mensalidade.dataPagamento,
      status: mensalidade.status,
      atrasada:
        mensalidade.status === MensalidadeStatus.PENDENTE &&
        mensalidade.dataVencimento < new Date(),
      motivoCancelamento: mensalidade.motivoCancelamento,
      formaPagamento: mensalidade.lancamento?.formaPagamento ?? null,
      createdAt: mensalidade.createdAt,
    };
  }
}
