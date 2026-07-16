import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

final _formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _formatoMoedaCompacta = NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$');

const _nomesMeses = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

const _nomesMesesAbrev = [
  'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
];

String _motivoLabel(MotivoCancelamento motivo) => switch (motivo) {
  MotivoCancelamento.alunoSolicitou => 'Aluno solicitou',
  MotivoCancelamento.inadimplencia => 'Inadimplência',
  MotivoCancelamento.academiaCancelou => 'Academia cancelou',
  MotivoCancelamento.outro => 'Outro',
};

/// Relatórios — Módulo 10 (roadmap original). Orquestra 3 endpoints só
/// leitura do backend (`RelatoriosService`): receita (delega pro Painel
/// Financeiro), alunos (novos x cancelamentos por mês) e resumo (snapshot
/// atual de ativos/retenção). Primeira tela do produto com gráfico de
/// verdade (`fl_chart`) — até aqui, "evolução mensal" sempre foi
/// lista/tabela (Painel Financeiro); ver docs/XX-relatorios-analise.md.
///
/// Sem curva histórica de "alunos ativos"/retenção — decisão de produto
/// (2026-07-16): sem histórico de status de Matrícula, não dá pra
/// reconstruir esse número com exatidão pra meses passados. `RelatorioResumo`
/// é sempre o retrato de agora, exibido como KPI, não como ponto de uma série.
class RelatoriosScreen extends ConsumerStatefulWidget {
  const RelatoriosScreen({super.key});

  @override
  ConsumerState<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends ConsumerState<RelatoriosScreen> {
  late int _mes;
  late int _ano;
  int _janelaMeses = 6;

  Future<List<EvolucaoMensalItem>>? _futureReceita;
  Future<List<RelatorioAlunosMensalItem>>? _futureAlunos;
  Future<RelatorioResumo>? _futureResumo;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mes = agora.month;
    _ano = agora.year;
    _carregar();
  }

  void _carregar() {
    setState(() {
      final api = ref.read(relatoriosApiProvider);
      _futureReceita = api.receita(mes: _mes, ano: _ano, meses: _janelaMeses);
      _futureAlunos = api.alunos(mes: _mes, ano: _ano, meses: _janelaMeses);
      // `resumo` sempre termina no mês corrente (snapshot de hoje) — a
      // âncora mes/ano do filtro não se aplica a ele, só `_janelaMeses`.
      _futureResumo = api.resumo(meses: _janelaMeses);
    });
  }

  void _aoMudarFiltro({int? mes, int? ano, int? janelaMeses}) {
    setState(() {
      _mes = mes ?? _mes;
      _ano = ano ?? _ano;
      _janelaMeses = janelaMeses ?? _janelaMeses;
    });
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final anoAtual = DateTime.now().year;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Relatórios', style: AppTypography.displayLarge.copyWith(color: colors.text)),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 170,
                  child: AppSelect<int>(
                    label: 'Mês',
                    value: _mes,
                    options: [
                      for (var i = 0; i < 12; i++) AppSelectOption(value: i + 1, label: _nomesMeses[i]),
                    ],
                    onChanged: (mes) => _aoMudarFiltro(mes: mes),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: AppSelect<int>(
                    label: 'Ano',
                    value: _ano,
                    options: [
                      for (var ano = anoAtual - 1; ano <= anoAtual + 1; ano++)
                        AppSelectOption(value: ano, label: '$ano'),
                    ],
                    onChanged: (ano) => _aoMudarFiltro(ano: ano),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: AppSelect<int>(
                    label: 'Janela',
                    value: _janelaMeses,
                    options: const [
                      AppSelectOption(value: 3, label: 'Últimos 3 meses'),
                      AppSelectOption(value: 6, label: 'Últimos 6 meses'),
                      AppSelectOption(value: 12, label: 'Últimos 12 meses'),
                    ],
                    onChanged: (janela) => _aoMudarFiltro(janelaMeses: janela),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FutureBuilder<RelatorioResumo>(
              future: _futureResumo,
              builder: (context, snapshot) {
                final resumo = snapshot.data;
                final carregando = !snapshot.hasData && !snapshot.hasError;
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    MetricCard(
                      label: 'Alunos ativos hoje',
                      value: resumo != null ? '${resumo.alunosAtivosHoje}' : '—',
                      icon: AppIcons.students,
                      loading: carregando,
                    ),
                    MetricCard(
                      label: 'Cancelamentos no período',
                      value: resumo != null ? '${resumo.cancelamentosPeriodo}' : '—',
                      icon: AppIcons.trendingDown,
                      loading: carregando,
                    ),
                    MetricCard(
                      label: 'Retenção aproximada',
                      value: resumo != null
                          ? '${(resumo.taxaRetencaoAproximada * 100).toStringAsFixed(0)}%'
                          : '—',
                      icon: AppIcons.reports,
                      highlight: true,
                      loading: carregando,
                      deltaLabel: 'Aproximação — ver detalhe abaixo',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('Evolução de receita', style: AppTypography.titleMedium.copyWith(color: colors.textMuted)),
            const SizedBox(height: AppSpacing.sm),
            FutureBuilder<List<EvolucaoMensalItem>>(
              future: _futureReceita,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _ChartSkeleton();
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: AppIcons.alert,
                    title: 'Não foi possível carregar a evolução de receita.',
                    actionLabel: 'Tentar novamente',
                    onAction: _carregar,
                  );
                }
                // API retorna mês âncora primeiro (mais recente); o gráfico
                // lê da esquerda pra direita como uma linha do tempo, então
                // inverte pra mais antigo -> mais recente.
                final itens = snapshot.data!.reversed.toList();
                return _ReceitaChart(itens: itens);
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Novos alunos x cancelamentos',
              style: AppTypography.titleMedium.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            FutureBuilder<List<RelatorioAlunosMensalItem>>(
              future: _futureAlunos,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _ChartSkeleton();
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: AppIcons.alert,
                    title: 'Não foi possível carregar novos alunos e cancelamentos.',
                    actionLabel: 'Tentar novamente',
                    onAction: _carregar,
                  );
                }
                final itens = snapshot.data!.reversed.toList();
                return _AlunosChart(itens: itens);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceitaChart extends StatelessWidget {
  const _ReceitaChart({required this.itens});

  final List<EvolucaoMensalItem> itens;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (itens.isEmpty || itens.every((i) => i.receitaPrevista == 0 && i.receitaRecebida == 0)) {
      return AppCard(child: EmptyState(icon: AppIcons.finance, title: 'Sem dados de receita no período'));
    }

    final maxValor = itens
        .expand((i) => [i.receitaPrevista, i.receitaRecebida])
        .fold<double>(0, (max, v) => v > max ? v : max);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Row(
              children: [
                _Legenda(cor: colors.textFaint, label: 'Prevista'),
                const SizedBox(width: AppSpacing.lg),
                _Legenda(cor: colors.primary, label: 'Recebida'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (itens.length - 1).toDouble(),
                minY: 0,
                maxY: maxValor <= 0 ? 100 : maxValor * 1.2,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxValor <= 0 ? 25 : (maxValor * 1.2) / 4,
                  getDrawingHorizontalLine: (_) => FlLine(color: colors.borderSoft, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 56,
                      getTitlesWidget: (value, meta) => Text(
                        _formatoMoedaCompacta.format(value),
                        style: AppTypography.bodySmall.copyWith(color: colors.textFaint, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= itens.length || i != value) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            '${_nomesMesesAbrev[itens[i].mes - 1]}/${itens[i].ano.toString().substring(2)}',
                            style: AppTypography.bodySmall.copyWith(color: colors.textFaint, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => colors.cardRaised,
                    getTooltipItems: (spots) => spots
                        .map(
                          (s) => LineTooltipItem(
                            _formatoMoeda.format(s.y),
                            AppTypography.bodySmall.copyWith(
                              color: s.barIndex == 0 ? colors.textMuted : colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < itens.length; i++) FlSpot(i.toDouble(), itens[i].receitaPrevista),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: colors.textFaint,
                    barWidth: 2,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < itens.length; i++) FlSpot(i.toDouble(), itens[i].receitaRecebida),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: colors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: colors.primaryWash),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlunosChart extends StatelessWidget {
  const _AlunosChart({required this.itens});

  final List<RelatorioAlunosMensalItem> itens;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (itens.isEmpty || itens.every((i) => i.novosAlunos == 0 && i.cancelamentos == 0)) {
      return AppCard(child: EmptyState(icon: AppIcons.students, title: 'Sem movimentação de alunos no período'));
    }

    final maxValor = itens
        .expand((i) => [i.novosAlunos, i.cancelamentos])
        .fold<int>(0, (max, v) => v > max ? v : max);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Row(
              children: [
                _Legenda(cor: colors.success, label: 'Novos alunos'),
                const SizedBox(width: AppSpacing.lg),
                _Legenda(cor: colors.error, label: 'Cancelamentos'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: maxValor <= 0 ? 5 : maxValor * 1.3,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: colors.borderSoft, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: maxValor <= 4 ? 1 : null,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: AppTypography.bodySmall.copyWith(color: colors.textFaint, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= itens.length || i != value) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            '${_nomesMesesAbrev[itens[i].mes - 1]}/${itens[i].ano.toString().substring(2)}',
                            style: AppTypography.bodySmall.copyWith(color: colors.textFaint, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colors.cardRaised,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = itens[groupIndex];
                      if (rodIndex == 1 && item.cancelamentos > 0) {
                        final motivos = item.cancelamentosPorMotivo
                            .where((m) => m.motivo != null)
                            .map((m) => '${_motivoLabel(m.motivo!)}: ${m.quantidade}')
                            .join('\n');
                        return BarTooltipItem(
                          '${rod.toY.toInt()}${motivos.isEmpty ? '' : '\n$motivos'}',
                          AppTypography.bodySmall.copyWith(color: colors.error, fontWeight: FontWeight.w600),
                        );
                      }
                      return BarTooltipItem(
                        rod.toY.toInt().toString(),
                        AppTypography.bodySmall.copyWith(
                          color: rodIndex == 0 ? colors.success : colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < itens.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: itens[i].novosAlunos.toDouble(),
                          color: colors.success,
                          width: 8,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        BarChartRodData(
                          toY: itens[i].cancelamentos.toDouble(),
                          color: colors.error,
                          width: 8,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                      barsSpace: 4,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.cor, required this.label});

  final Color cor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(2)),
          child: const SizedBox(width: 10, height: 10),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTypography.bodySmall.copyWith(color: context.colors.textMuted)),
      ],
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: SizedBox(
        height: 240,
        child: Center(child: LoadingSkeleton(width: double.infinity, height: 200)),
      ),
    );
  }
}
