import { Injectable } from '@nestjs/common';
import { MatriculaStatus, UserStatus } from '@prisma/client';
import { RelatoriosEvolucaoQueryDto } from './dto/relatorios-evolucao-query.dto';
import { RelatoriosResumoQueryDto } from './dto/relatorios-resumo-query.dto';
import { RelatoriosResumoResponseDto } from './dto/relatorios-resumo-response.dto';
import {
  AlunosMensalItemDto,
  RelatoriosAlunosResponseDto,
} from './dto/relatorios-alunos-response.dto';
import { DashboardFinanceiroService } from '../financeiro/dashboard/dashboard-financeiro.service';
import { DashboardEvolucaoResponseDto } from '../financeiro/dashboard/dto/dashboard-evolucao-response.dto';
import { intervaloDoMes, mesRecuado } from '../financeiro/financeiro.util';
import { PrismaService } from '../../prisma/prisma.service';

/// Só orquestra/agrega dado que já existe (Financeiro, Matrículas, Aluno)
/// — nenhuma regra de negócio nova de domínio aqui, mesmo espírito de
/// `DashboardFinanceiroService`/`DashboardService`.
@Injectable()
export class RelatoriosService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly dashboardFinanceiroService: DashboardFinanceiroService,
  ) {}

  /// Delega pro Painel Financeiro — receita por período já existe lá
  /// (evolução mensal), Relatórios só reexpõe sob o mesmo namespace.
  receita(query: RelatoriosEvolucaoQueryDto): Promise<DashboardEvolucaoResponseDto> {
    return this.dashboardFinanceiroService.evolucao(query);
  }

  async alunos(query: RelatoriosEvolucaoQueryDto): Promise<RelatoriosAlunosResponseDto> {
    const agora = new Date();
    const mesAncora = query.mes ?? agora.getUTCMonth() + 1;
    const anoAncora = query.ano ?? agora.getUTCFullYear();
    const quantidadeMeses = query.meses ?? 6;

    const janela = Array.from({ length: quantidadeMeses }, (_, i) =>
      mesRecuado(mesAncora, anoAncora, i),
    );

    const meses = await Promise.all(janela.map(({ mes, ano }) => this.alunosDoMes(mes, ano)));

    return { meses };
  }

  /// Snapshot atual (não histórico): sem uma tabela de histórico de status
  /// de Matrícula, não dá pra reconstruir "quantos alunos estavam ativos no
  /// fim do mês X" pra meses passados — decisão explícita do dono do
  /// produto (2026-07-16) foi não fingir essa precisão. `taxaRetencaoAproximada`
  /// usa "ativos hoje + perdidos na janela" como proxy da base inicial do
  /// período — aproximação intencional, não um número exato mês a mês.
  async resumo(query: RelatoriosResumoQueryDto): Promise<RelatoriosResumoResponseDto> {
    const quantidadeMeses = query.meses ?? 6;
    const agora = new Date();
    const mesAncora = agora.getUTCMonth() + 1;
    const anoAncora = agora.getUTCFullYear();
    const mesMaisAntigo = mesRecuado(mesAncora, anoAncora, quantidadeMeses - 1);

    const inicioPeriodo = intervaloDoMes(mesMaisAntigo.mes, mesMaisAntigo.ano).inicio;
    const fimPeriodo = intervaloDoMes(mesAncora, anoAncora).fim;

    const [alunosAtivosHoje, cancelamentosPeriodo] = await Promise.all([
      this.prisma.forTenant().aluno.count({ where: { deletedAt: null, status: UserStatus.ATIVO } }),
      this.prisma.forTenant().matricula.count({
        where: {
          status: MatriculaStatus.CANCELADA,
          deletedAt: null,
          updatedAt: { gte: inicioPeriodo, lt: fimPeriodo },
        },
      }),
    ]);

    const base = alunosAtivosHoje + cancelamentosPeriodo;
    const taxaRetencaoAproximada =
      base === 0 ? 1 : Math.round((1 - cancelamentosPeriodo / base) * 1000) / 1000;

    return {
      meses: quantidadeMeses,
      alunosAtivosHoje,
      cancelamentosPeriodo,
      taxaRetencaoAproximada,
    };
  }

  private async alunosDoMes(mes: number, ano: number): Promise<AlunosMensalItemDto> {
    const { inicio, fim } = intervaloDoMes(mes, ano);

    const [novosAlunos, cancelamentosPorMotivo] = await Promise.all([
      // Exclui renovações (`matriculaAnteriorId` preenchido) — `renovar()`
      // cria uma linha nova pro mesmo aluno, isso não é um aluno novo
      // entrando (docs/16, item 12).
      this.prisma.forTenant().matricula.count({
        where: { dataInicio: { gte: inicio, lt: fim }, matriculaAnteriorId: null, deletedAt: null },
      }),
      // `updatedAt` como data do cancelamento: `cancelar()` não mexe em
      // `dataFim`, só em `status`/`motivoCancelamento` — e depois de
      // CANCELADA a matrícula é terminal (nunca mais atualizada), então
      // `updatedAt` fica estável como a data real da transição.
      this.prisma.forTenant().matricula.groupBy({
        by: ['motivoCancelamento'],
        where: {
          status: MatriculaStatus.CANCELADA,
          deletedAt: null,
          updatedAt: { gte: inicio, lt: fim },
        },
        _count: true,
      }),
    ]);

    const cancelamentos = cancelamentosPorMotivo.reduce((soma, g) => soma + g._count, 0);

    return {
      mes,
      ano,
      novosAlunos,
      cancelamentos,
      cancelamentosPorMotivo: cancelamentosPorMotivo.map((g) => ({
        motivo: g.motivoCancelamento,
        quantidade: g._count,
      })),
      saldoLiquido: novosAlunos - cancelamentos,
    };
  }
}
