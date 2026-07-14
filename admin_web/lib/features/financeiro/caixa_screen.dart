import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

final _formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

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

/// Caixa — Módulo 3 (MS4). Livro-caixa por competência, não um cadastro
/// genérico de Lançamentos: a maioria dos lançamentos nasce sozinha
/// (`Lancamento` gerado por `MensalidadesService.marcarPaga`), o que
/// importa aqui é a soma (resumo de entradas/saídas/saldo do mês), não o
/// registro isolado (ver docs/17-modulo-3-financeiro-analise.md, seção
/// "MS4 — Lançamento é cadastro ou Livro Caixa?"). Mesmo eixo de
/// competência (mês/ano) já consolidado em Mensalidades.
///
/// `origem` (`LancamentoOrigem`) decide a interação da linha: `manual` abre
/// `_AcoesLancamentoDialog` (editar/remover); `mensalidade` é somente
/// leitura e navega até a Mensalidade correspondente (competência +
/// aluno), já que este módulo não tem tela de Detalhe própria pra
/// Mensalidade.
///
/// Nenhum componente novo do Design System — `MetricCard` (já previsto
/// desde o Dashboard pra "Financeiro/Relatórios futuros"), `AppCard`,
/// `AppListTile`, `AppSelect`, `AppPagination` de sempre.
class CaixaScreen extends ConsumerStatefulWidget {
  const CaixaScreen({super.key});

  @override
  ConsumerState<CaixaScreen> createState() => _CaixaScreenState();
}

class _CaixaScreenState extends ConsumerState<CaixaScreen> {
  late int _mes;
  late int _ano;
  LancamentoTipo? _tipoFiltro;
  int _pagina = 1;
  static const _tamanhoPagina = 20;

  Future<PaginatedResult<Lancamento>>? _future;
  Future<ResumoLancamentos>? _futureResumo;

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
      _future = ref
          .read(lancamentosApiProvider)
          .listLancamentos(
            tipo: _tipoFiltro,
            mes: _mes,
            ano: _ano,
            page: _pagina,
            pageSize: _tamanhoPagina,
          );
      _futureResumo = ref.read(lancamentosApiProvider).resumo(mes: _mes, ano: _ano);
    });
  }

  void _aoFiltrarTipo(LancamentoTipo? tipo) {
    setState(() {
      _tipoFiltro = tipo;
      _pagina = 1;
    });
    _carregar();
  }

  void _aoMudarCompetencia({int? mes, int? ano}) {
    setState(() {
      _mes = mes ?? _mes;
      _ano = ano ?? _ano;
      _pagina = 1;
    });
    _carregar();
  }

  void _limparFiltros() {
    setState(() {
      _tipoFiltro = null;
      _pagina = 1;
    });
    _carregar();
  }

  void _irParaPagina(int pagina) {
    setState(() => _pagina = pagina);
    _carregar();
  }

  Future<void> _novoLancamento() async {
    final criado = await showDialog<bool>(
      context: context,
      builder: (_) => const _NovoLancamentoDialog(),
    );
    if (criado == true) _carregar();
  }

  Future<void> _abrirLinha(Lancamento lancamento) async {
    if (lancamento.origem == LancamentoOrigem.mensalidade) {
      final vencimento = lancamento.mensalidadeDataVencimento!;
      context.go(
        '/financeiro/mensalidades'
        '?mes=${vencimento.month}&ano=${vencimento.year}'
        '&busca=${Uri.encodeComponent(lancamento.alunoNome ?? '')}',
      );
      return;
    }
    final alterou = await showDialog<bool>(
      context: context,
      builder: (_) => _AcoesLancamentoDialog(lancamento: lancamento),
    );
    if (alterou == true) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final temFiltroAtivo = _tipoFiltro != null;
    final anoAtual = DateTime.now().year;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Caixa', style: AppTypography.displayLarge.copyWith(color: colors.text)),
            const SizedBox(height: AppSpacing.xl),
            // Competência — eixo principal da tela, mesmo padrão de Mensalidades.
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
            // Resumo financeiro do período — sempre o do mês selecionado, nunca
            // acumulado (visão histórica multi-mês fica pro MS5).
            FutureBuilder<ResumoLancamentos>(
              future: _futureResumo,
              builder: (context, snapshot) {
                final resumo = snapshot.data;
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    MetricCard(
                      label: 'Receitas',
                      value: resumo != null ? _formatoMoeda.format(resumo.totalReceitas) : '—',
                      icon: AppIcons.trendingUp,
                      loading: !snapshot.hasData && !snapshot.hasError,
                      deltaLabel: resumo != null ? '${resumo.quantidadeReceitas} lançamento(s)' : null,
                    ),
                    MetricCard(
                      label: 'Despesas',
                      value: resumo != null ? _formatoMoeda.format(resumo.totalDespesas) : '—',
                      icon: AppIcons.trendingDown,
                      loading: !snapshot.hasData && !snapshot.hasError,
                      deltaLabel: resumo != null ? '${resumo.quantidadeDespesas} lançamento(s)' : null,
                    ),
                    MetricCard(
                      label: 'Saldo do mês',
                      value: resumo != null ? _formatoMoeda.format(resumo.saldo) : '—',
                      icon: AppIcons.finance,
                      highlight: true,
                      loading: !snapshot.hasData && !snapshot.hasError,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 190,
                  child: AppSelect<LancamentoTipo?>(
                    label: 'Tipo',
                    value: _tipoFiltro,
                    options: const [
                      AppSelectOption(value: null, label: 'Todos os tipos'),
                      AppSelectOption(value: LancamentoTipo.receita, label: 'Receita'),
                      AppSelectOption(value: LancamentoTipo.despesa, label: 'Despesa'),
                    ],
                    onChanged: _aoFiltrarTipo,
                  ),
                ),
                AppButton(label: 'Novo lançamento', icon: AppIcons.add, onPressed: _novoLancamento),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FutureBuilder<PaginatedResult<Lancamento>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _CaixaListaSkeleton();
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: AppIcons.alert,
                    title: 'Não foi possível carregar o caixa.',
                    actionLabel: 'Tentar novamente',
                    onAction: _carregar,
                  );
                }
                final resultado = snapshot.data!;
                if (resultado.items.isEmpty) {
                  return EmptyState(
                    icon: AppIcons.finance,
                    title: temFiltroAtivo
                        ? 'Nenhum lançamento encontrado'
                        : 'Nenhum lançamento em ${_nomesMeses[_mes - 1]}/$_ano',
                    description: temFiltroAtivo
                        ? 'Ajuste o filtro e tente de novo.'
                        : 'Lançamentos de mensalidades pagas aparecem aqui automaticamente. Registre uma receita ou despesa manual pra começar.',
                    actionLabel: temFiltroAtivo ? 'Limpar filtros' : 'Novo lançamento',
                    onAction: temFiltroAtivo ? _limparFiltros : _novoLancamento,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.lg),
                      child: Column(
                        children: [
                          for (var i = 0; i < resultado.items.length; i++) ...[
                            if (i > 0) Divider(color: colors.borderSoft, height: 1),
                            _LancamentoRow(
                              lancamento: resultado.items[i],
                              onTap: () => _abrirLinha(resultado.items[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppPagination(
                      page: resultado.page,
                      pageSize: resultado.pageSize,
                      total: resultado.total,
                      onPageChanged: _irParaPagina,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LancamentoRow extends StatelessWidget {
  final Lancamento lancamento;
  final VoidCallback onTap;

  const _LancamentoRow({required this.lancamento, required this.onTap});

  bool get _receita => lancamento.tipo == LancamentoTipo.receita;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cor = _receita ? colors.success : colors.error;
    final sinal = _receita ? '+' : '−';
    final automatico = lancamento.origem == LancamentoOrigem.mensalidade;

    return AppListTile(
      title: lancamento.descricao,
      subtitle: [
        dataCurtaFormat.format(lancamento.data),
        if (lancamento.categoria != null) lancamento.categoria!,
      ].join(' · '),
      leadingText: _receita ? 'R' : 'D',
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$sinal ${_formatoMoeda.format(lancamento.valor)}',
            style: AppTypography.mono.copyWith(color: cor, fontSize: 13),
          ),
          if (automatico) ...[
            const SizedBox(height: AppSpacing.xs),
            const AppBadge('Automático', tone: AppBadgeTone.neutral),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

class _CaixaListaSkeleton extends StatelessWidget {
  const _CaixaListaSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
      child: Column(
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) Divider(color: colors.borderSoft, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  const LoadingSkeleton(width: 34, height: 34, shape: AppSkeletonShape.circle),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LoadingSkeleton(width: 160 - (i * 10), height: 12),
                        const SizedBox(height: AppSpacing.sm),
                        const LoadingSkeleton(width: 120, height: 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const LoadingSkeleton(width: 56, height: 20),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Registro de receita/despesa manual — sem tela de Detalhe própria (mesmo
/// motivo de `_AcoesMensalidadeDialog`): não há ciclo de vida a exibir,
/// só os campos do lançamento.
class _NovoLancamentoDialog extends ConsumerStatefulWidget {
  const _NovoLancamentoDialog();

  @override
  ConsumerState<_NovoLancamentoDialog> createState() => _NovoLancamentoDialogState();
}

class _NovoLancamentoDialogState extends ConsumerState<_NovoLancamentoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _categoriaController = TextEditingController();
  final _valorController = TextEditingController();

  LancamentoTipo _tipo = LancamentoTipo.despesa;
  late DateTime _data;
  FormaPagamento? _formaPagamento;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Sem isso, AppDateField abre o seletor no `lastDate` (não em "hoje")
    // quando o campo começa vazio — mesmo achado já registrado no
    // formulário de Matrícula (docs/15).
    _data = DateTime.now();
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _categoriaController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await ref
          .read(lancamentosApiProvider)
          .create({
            'tipo': _tipo.wireValue,
            'descricao': _descricaoController.text.trim(),
            'categoria': _categoriaController.text.trim().isEmpty
                ? null
                : _categoriaController.text.trim(),
            'valor': double.parse(_valorController.text.trim().replaceAll(',', '.')),
            'data': _data.toIso8601String(),
            'formaPagamento': _formaPagamento?.wireValue,
          });
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Dialog(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Novo lançamento', style: AppTypography.titleLarge.copyWith(color: colors.text)),
                const SizedBox(height: AppSpacing.lg),
                AppFormRow(
                  children: [
                    AppSelect<LancamentoTipo>(
                      label: 'Tipo',
                      value: _tipo,
                      options: const [
                        AppSelectOption(value: LancamentoTipo.receita, label: 'Receita'),
                        AppSelectOption(value: LancamentoTipo.despesa, label: 'Despesa'),
                      ],
                      onChanged: (tipo) => setState(() => _tipo = tipo ?? _tipo),
                    ),
                    AppDateField(
                      label: 'Data',
                      value: _data,
                      firstDate: DateTime(DateTime.now().year - 5),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      onChanged: (data) => setState(() => _data = data ?? _data),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Descrição',
                  controller: _descricaoController,
                  validator: (v) => (v == null || v.trim().length < 2) ? 'Informe a descrição' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppFormRow(
                  children: [
                    AppTextField(label: 'Categoria (opcional)', controller: _categoriaController),
                    AppTextField(
                      label: 'Valor',
                      controller: _valorController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final numero = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                        if (numero == null || numero <= 0) return 'Informe um valor válido';
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppSelect<FormaPagamento?>(
                  label: 'Forma de pagamento (opcional)',
                  value: _formaPagamento,
                  options: const [
                    AppSelectOption(value: null, label: 'Não informar'),
                    AppSelectOption(value: FormaPagamento.dinheiro, label: 'Dinheiro'),
                    AppSelectOption(value: FormaPagamento.pix, label: 'PIX'),
                    AppSelectOption(value: FormaPagamento.cartaoCredito, label: 'Cartão de crédito'),
                    AppSelectOption(value: FormaPagamento.cartaoDebito, label: 'Cartão de débito'),
                    AppSelectOption(value: FormaPagamento.boleto, label: 'Boleto'),
                    AppSelectOption(value: FormaPagamento.outro, label: 'Outro'),
                  ],
                  onChanged: (v) => setState(() => _formaPagamento = v),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppFormErrorBanner(_erro!),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: 'Cancelar',
                      variant: AppButtonVariant.secondary,
                      onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton(label: 'Salvar', loading: _salvando, onPressed: _salvar),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _AcaoView { menu, editar }

/// Ações rápidas de um lançamento manual — só chamado para
/// `origem == LancamentoOrigem.manual` (mensalidade-origem nunca abre
/// este diálogo, ver `_CaixaScreenState._abrirLinha`). Mesmo chassi de
/// `_AcoesMensalidadeDialog`/`_CancelarMatriculaDialog`.
class _AcoesLancamentoDialog extends ConsumerStatefulWidget {
  const _AcoesLancamentoDialog({required this.lancamento});

  final Lancamento lancamento;

  @override
  ConsumerState<_AcoesLancamentoDialog> createState() => _AcoesLancamentoDialogState();
}

class _AcoesLancamentoDialogState extends ConsumerState<_AcoesLancamentoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descricaoController;
  late final TextEditingController _categoriaController;
  late final TextEditingController _valorController;

  _AcaoView _view = _AcaoView.menu;
  late LancamentoTipo _tipo;
  late DateTime _data;
  FormaPagamento? _formaPagamento;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final l = widget.lancamento;
    _descricaoController = TextEditingController(text: l.descricao);
    _categoriaController = TextEditingController(text: l.categoria ?? '');
    _valorController = TextEditingController(text: l.valor.toStringAsFixed(2).replaceAll('.', ','));
    _tipo = l.tipo;
    _data = l.data;
    _formaPagamento = l.formaPagamento;
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _categoriaController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _salvarEdicao() async {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await ref
          .read(lancamentosApiProvider)
          .update(widget.lancamento.id, {
            'tipo': _tipo.wireValue,
            'descricao': _descricaoController.text.trim(),
            'categoria': _categoriaController.text.trim().isEmpty
                ? null
                : _categoriaController.text.trim(),
            'valor': double.parse(_valorController.text.trim().replaceAll(',', '.')),
            'data': _data.toIso8601String(),
            'formaPagamento': _formaPagamento?.wireValue,
          });
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _remover() async {
    final confirmou = await AppConfirmDialog.show(
      context,
      variant: AppConfirmDialogVariant.danger,
      title: 'Remover lançamento',
      description: 'Some da lista, mas nada é apagado permanentemente.',
      confirmLabel: 'Remover',
    );
    if (confirmou != true || !mounted) return;

    setState(() => _salvando = true);
    try {
      await ref.read(lancamentosApiProvider).remove(widget.lancamento.id);
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (mounted) setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lancamento = widget.lancamento;

    return Dialog(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lancamento.descricao, style: AppTypography.titleLarge.copyWith(color: colors.text)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${dataCurtaFormat.format(lancamento.data)} · ${_formatoMoeda.format(lancamento.valor)}',
                style: AppTypography.bodyMedium.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_view == _AcaoView.menu) ..._menu(),
              if (_view == _AcaoView.editar) ..._formEditar(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _menu() {
    return [
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          AppButton(
            label: 'Editar',
            icon: AppIcons.edit,
            onPressed: () => setState(() => _view = _AcaoView.editar),
          ),
          AppButton(
            label: 'Remover',
            icon: AppIcons.trash,
            variant: AppButtonVariant.danger,
            loading: _salvando,
            onPressed: _remover,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      Align(
        alignment: Alignment.centerRight,
        child: AppButton(
          label: 'Fechar',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
    ];
  }

  List<Widget> _formEditar() {
    return [
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppFormRow(
              children: [
                AppSelect<LancamentoTipo>(
                  label: 'Tipo',
                  value: _tipo,
                  options: const [
                    AppSelectOption(value: LancamentoTipo.receita, label: 'Receita'),
                    AppSelectOption(value: LancamentoTipo.despesa, label: 'Despesa'),
                  ],
                  onChanged: (tipo) => setState(() => _tipo = tipo ?? _tipo),
                ),
                AppDateField(
                  label: 'Data',
                  value: _data,
                  firstDate: DateTime(DateTime.now().year - 5),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onChanged: (data) => setState(() => _data = data ?? _data),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Descrição',
              controller: _descricaoController,
              validator: (v) => (v == null || v.trim().length < 2) ? 'Informe a descrição' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppFormRow(
              children: [
                AppTextField(label: 'Categoria (opcional)', controller: _categoriaController),
                AppTextField(
                  label: 'Valor',
                  controller: _valorController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final numero = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                    if (numero == null || numero <= 0) return 'Informe um valor válido';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppSelect<FormaPagamento?>(
              label: 'Forma de pagamento (opcional)',
              value: _formaPagamento,
              options: const [
                AppSelectOption(value: null, label: 'Não informar'),
                AppSelectOption(value: FormaPagamento.dinheiro, label: 'Dinheiro'),
                AppSelectOption(value: FormaPagamento.pix, label: 'PIX'),
                AppSelectOption(value: FormaPagamento.cartaoCredito, label: 'Cartão de crédito'),
                AppSelectOption(value: FormaPagamento.cartaoDebito, label: 'Cartão de débito'),
                AppSelectOption(value: FormaPagamento.boleto, label: 'Boleto'),
                AppSelectOption(value: FormaPagamento.outro, label: 'Outro'),
              ],
              onChanged: (v) => setState(() => _formaPagamento = v),
            ),
          ],
        ),
      ),
      if (_erro != null) ...[
        const SizedBox(height: AppSpacing.md),
        AppFormErrorBanner(_erro!),
      ],
      const SizedBox(height: AppSpacing.xl),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppButton(
            label: 'Voltar',
            variant: AppButtonVariant.secondary,
            onPressed: _salvando ? null : () => setState(() => _view = _AcaoView.menu),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(label: 'Salvar', loading: _salvando, onPressed: _salvarEdicao),
        ],
      ),
    ];
  }
}

