import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

final _formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _formatoMoedaSemCifrao = NumberFormat.currency(locale: 'pt_BR', symbol: '');

const _nomesMeses = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

const _nomesMesesAbrev = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

String _taxaLabel(double? taxa) => taxa == null ? '—' : '${(taxa * 100).toStringAsFixed(0)}%';

/// Painel Financeiro Gerencial — Módulo 3 (MS5). Não é "mais um Fluxo de
/// Caixa" (isso já é o MS4/Caixa): aqui o eixo é gerencial — receita
/// prevista vs. recebida (taxa de recebimento), inadimplência (sempre
/// tempo real, não escopada à competência) e evolução mensal — as
/// perguntas que o dono da academia faz ao revisar o mês, não ao lançar
/// uma transação (docs/17, seção "MS5 — Fluxo de Caixa ou Painel
/// Financeiro Gerencial?").
///
/// `/financeiro/dashboard` (resumo) e `/financeiro/dashboard/evolucao` já
/// vêm agregados do backend (`DashboardFinanceiroService` orquestrando
/// Mensalidades + Lançamentos) — o frontend só calcula a taxa de
/// recebimento (`recebida / prevista`, `ResumoFinanceiro.taxaRecebimento`)
/// e formata; nenhuma soma é refeita aqui.
///
/// Evolução mensal é lista/tabela, não gráfico — nenhuma biblioteca de
/// chart no projeto ainda; evolui pra gráfico só se um caso real pedir
/// (mesmo critério de `AppAutocompleteField`/scheduler). Nenhum
/// componente novo do Design System — `MetricCard`, `AppCard`, `AppSelect`
/// de sempre.
class PainelFinanceiroScreen extends ConsumerStatefulWidget {
  const PainelFinanceiroScreen({super.key});

  @override
  ConsumerState<PainelFinanceiroScreen> createState() => _PainelFinanceiroScreenState();
}

class _PainelFinanceiroScreenState extends ConsumerState<PainelFinanceiroScreen> {
  late int _mes;
  late int _ano;

  Future<ResumoFinanceiro>? _futureResumo;
  Future<List<EvolucaoMensalItem>>? _futureEvolucao;

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
      _futureResumo = ref.read(dashboardFinanceiroApiProvider).resumo(mes: _mes, ano: _ano);
      _futureEvolucao = ref.read(dashboardFinanceiroApiProvider).evolucao(mes: _mes, ano: _ano);
    });
  }

  void _aoMudarCompetencia({int? mes, int? ano}) {
    setState(() {
      _mes = mes ?? _mes;
      _ano = ano ?? _ano;
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
            Text('Painel Financeiro', style: AppTypography.displayLarge.copyWith(color: colors.text)),
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
                    onChanged: (mes) => _aoMudarCompetencia(mes: mes),
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
                    onChanged: (ano) => _aoMudarCompetencia(ano: ano),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FutureBuilder<ResumoFinanceiro>(
              future: _futureResumo,
              builder: (context, snapshot) {
                final resumo = snapshot.data;
                final carregando = !snapshot.hasData && !snapshot.hasError;
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    MetricCard(
                      label: 'Receita Prevista',
                      value: resumo != null ? _formatoMoeda.format(resumo.receitaPrevista) : '—',
                      icon: AppIcons.calendar,
                      loading: carregando,
                    ),
                    MetricCard(
                      label: 'Receita Recebida',
                      value: resumo != null ? _formatoMoeda.format(resumo.receitaRecebida) : '—',
                      icon: AppIcons.trendingUp,
                      loading: carregando,
                      deltaLabel: resumo != null ? '${_taxaLabel(resumo.taxaRecebimento)} da prevista' : null,
                    ),
                    MetricCard(
                      label: 'Inadimplência',
                      value: resumo != null ? _formatoMoeda.format(resumo.inadimplenciaValor) : '—',
                      icon: AppIcons.alert,
                      loading: carregando,
                      deltaLabel: resumo != null ? '${resumo.inadimplenciaQuantidade} mensalidade(s)' : null,
                    ),
                    MetricCard(
                      label: 'Despesas',
                      value: resumo != null ? _formatoMoeda.format(resumo.despesas) : '—',
                      icon: AppIcons.trendingDown,
                      loading: carregando,
                    ),
                    MetricCard(
                      label: 'Saldo do mês',
                      value: resumo != null ? _formatoMoeda.format(resumo.saldo) : '—',
                      icon: AppIcons.finance,
                      highlight: true,
                      loading: carregando,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('Evolução mensal', style: AppTypography.titleMedium.copyWith(color: colors.textMuted)),
            const SizedBox(height: AppSpacing.sm),
            FutureBuilder<List<EvolucaoMensalItem>>(
              future: _futureEvolucao,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _EvolucaoSkeleton();
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: AppIcons.alert,
                    title: 'Não foi possível carregar a evolução mensal.',
                    actionLabel: 'Tentar novamente',
                    onAction: _carregar,
                  );
                }
                return _EvolucaoTabela(itens: snapshot.data!);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Sem nenhum lançamento/mensalidade no período — comum numa academia
/// recém-cadastrada (o piloto vai ver isso no primeiro acesso). Antes
/// disso, a tabela renderizava só o cabeçalho, sem nenhuma linha nem
/// explicação (Sprint 31, Release Blockers v1.0 — docs/30, achado
/// Crítico). Mesmo critério de "tudo zero" já usado em
/// `relatorios_screen.dart`.
bool _semDadoFinanceiro(List<EvolucaoMensalItem> itens) {
  return itens.isEmpty ||
      itens.every((i) => i.receitaPrevista == 0 && i.receitaRecebida == 0 && i.despesas == 0);
}

class _EvolucaoTabela extends StatelessWidget {
  const _EvolucaoTabela({required this.itens});

  final List<EvolucaoMensalItem> itens;

  @override
  Widget build(BuildContext context) {
    if (_semDadoFinanceiro(itens)) {
      return AppCard(
        child: EmptyState(
          icon: AppIcons.finance,
          title: 'Nenhum dado financeiro neste período',
          description: 'Assim que houver mensalidades geradas ou lançamentos registrados, a evolução mensal aparece aqui.',
        ),
      );
    }

    if (context.isMobile) {
      return Column(
        children: [
          for (var i = 0; i < itens.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _EvolucaoCardMobile(item: itens[i]),
          ],
        ],
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const _LinhaEvolucao.cabecalho(),
          Divider(color: context.colors.borderSoft, height: 1),
          for (var i = 0; i < itens.length; i++) ...[
            if (i > 0) Divider(color: context.colors.borderSoft, height: 1),
            _LinhaEvolucao(item: itens[i]),
          ],
        ],
      ),
    );
  }
}

class _LinhaEvolucao extends StatelessWidget {
  const _LinhaEvolucao({required EvolucaoMensalItem this.item}) : cabecalho = false;
  const _LinhaEvolucao.cabecalho() : item = null, cabecalho = true;

  final EvolucaoMensalItem? item;
  final bool cabecalho;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelStyle = AppTypography.bodySmall.copyWith(
      color: colors.textFaint,
      fontWeight: FontWeight.w600,
    );

    if (cabecalho) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text('Mês', style: labelStyle)),
            Expanded(child: Text('Prevista', style: labelStyle, textAlign: TextAlign.right)),
            Expanded(child: Text('Recebida', style: labelStyle, textAlign: TextAlign.right)),
            Expanded(child: Text('Despesas', style: labelStyle, textAlign: TextAlign.right)),
            Expanded(child: Text('Saldo', style: labelStyle, textAlign: TextAlign.right)),
            Expanded(child: Text('Taxa', style: labelStyle, textAlign: TextAlign.right)),
          ],
        ),
      );
    }

    final it = item!;
    final valueStyle = AppTypography.mono.copyWith(color: colors.text, fontSize: 13);
    final saldoStyle = valueStyle.copyWith(color: it.saldo >= 0 ? colors.success : colors.error);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '${_nomesMesesAbrev[it.mes - 1]}/${it.ano}',
              style: AppTypography.bodyMedium.copyWith(color: colors.text),
            ),
          ),
          Expanded(
            child: Text(_formatoMoedaSemCifrao.format(it.receitaPrevista), style: valueStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            child: Text(_formatoMoedaSemCifrao.format(it.receitaRecebida), style: valueStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            child: Text(_formatoMoedaSemCifrao.format(it.despesas), style: valueStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            child: Text(_formatoMoedaSemCifrao.format(it.saldo), style: saldoStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            child: Text(_taxaLabel(it.taxaRecebimento), style: valueStyle, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _EvolucaoCardMobile extends StatelessWidget {
  const _EvolucaoCardMobile({required this.item});

  final EvolucaoMensalItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_nomesMeses[item.mes - 1]}/${item.ano}',
            style: AppTypography.titleMedium.copyWith(color: colors.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          _linhaMobile(context, 'Receita prevista', _formatoMoeda.format(item.receitaPrevista)),
          _linhaMobile(context, 'Receita recebida', _formatoMoeda.format(item.receitaRecebida)),
          _linhaMobile(context, 'Despesas', _formatoMoeda.format(item.despesas)),
          _linhaMobile(
            context,
            'Saldo',
            _formatoMoeda.format(item.saldo),
            valorColor: item.saldo >= 0 ? colors.success : colors.error,
          ),
          _linhaMobile(context, 'Taxa de recebimento', _taxaLabel(item.taxaRecebimento)),
        ],
      ),
    );
  }

  Widget _linhaMobile(BuildContext context, String label, String valor, {Color? valorColor}) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall.copyWith(color: colors.textMuted)),
          Text(
            valor,
            style: AppTypography.mono.copyWith(color: valorColor ?? colors.text, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _EvolucaoSkeleton extends StatelessWidget {
  const _EvolucaoSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
      child: Column(
        children: [
          for (var i = 0; i < 6; i++) ...[
            if (i > 0) Divider(color: colors.borderSoft, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  LoadingSkeleton(width: 80 - (i * 2), height: 12),
                  const Spacer(),
                  const LoadingSkeleton(width: 200, height: 12),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
