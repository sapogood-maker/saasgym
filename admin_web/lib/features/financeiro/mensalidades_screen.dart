import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Lista de mensalidades — Módulo 3 (MS3). Diferente de Alunos/
/// Professores/Planos/Matrículas (que carregam "tudo" por padrão), esta
/// tela é **orientada por competência**: carrega, por padrão, só o mês
/// corrente — a ação mais importante da tela (`gerar`) não existe sem um
/// mês/ano selecionado, e o fluxo real do dono da academia é "o que
/// preciso cobrar/conferir este mês", não "procurar uma mensalidade".
/// Busca por aluno e filtro de status continuam existindo, mas como
/// complemento (dentro do `AppListToolbar` de sempre) — mês/ano fica
/// destacado acima, junto do botão "Gerar mensalidades do mês".
///
/// "Atrasada" (`Mensalidade.atrasada`, já calculado pelo backend) não
/// virou uma dimensão de filtro nova — aparece como um tom de badge
/// distinto (vermelho) na própria linha, dando visibilidade ao status
/// financeiro sem inventar parâmetro sem necessidade comprovada (ver
/// docs/17-modulo-3-financeiro-analise.md).
///
/// Nenhum componente novo do Design System — `AppListToolbar`+`AppCard`+
/// `AppListTile`+`AppPagination` de sempre, mais um diálogo próprio de
/// ações rápidas (`_AcoesMensalidadeDialog`, mesma composição de
/// `_CancelarMatriculaDialog` em Matrículas) porque não há uma tela de
/// Detalhe própria pra Mensalidade neste módulo (MS4/MS5 são Lançamentos/
/// Fluxo de caixa, não um detalhe de Mensalidade).
class MensalidadesScreen extends ConsumerStatefulWidget {
  const MensalidadesScreen({super.key, this.initialMes, this.initialAno, this.initialBusca});

  /// Competência/busca iniciais — usados quando se chega aqui a partir de
  /// outra tela (ex.: linha de Lançamento gerado por Mensalidade, no
  /// Caixa) em vez do mês corrente/sem filtro de sempre.
  final int? initialMes;
  final int? initialAno;
  final String? initialBusca;

  @override
  ConsumerState<MensalidadesScreen> createState() => _MensalidadesScreenState();
}

class _MensalidadesScreenState extends ConsumerState<MensalidadesScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  late int _mes;
  late int _ano;
  String _search = '';
  MensalidadeStatus? _statusFiltro;
  int _pagina = 1;
  static const _tamanhoPagina = 20;
  bool _gerando = false;

  Future<PaginatedResult<Mensalidade>>? _future;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mes = widget.initialMes ?? agora.month;
    _ano = widget.initialAno ?? agora.year;
    if (widget.initialBusca != null && widget.initialBusca!.isNotEmpty) {
      _search = widget.initialBusca!;
      _searchController.text = widget.initialBusca!;
    }
    _carregar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _carregar() {
    setState(() {
      _future = ref
          .read(mensalidadesApiProvider)
          .listMensalidades(
            search: _search,
            status: _statusFiltro,
            mes: _mes,
            ano: _ano,
            page: _pagina,
            pageSize: _tamanhoPagina,
          );
    });
  }

  void _aoBuscar(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search = valor;
      _pagina = 1;
      _carregar();
    });
  }

  void _aoFiltrarStatus(MensalidadeStatus? status) {
    setState(() {
      _statusFiltro = status;
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
    _searchController.clear();
    setState(() {
      _search = '';
      _statusFiltro = null;
      _pagina = 1;
    });
    _carregar();
  }

  void _irParaPagina(int pagina) {
    setState(() => _pagina = pagina);
    _carregar();
  }

  Future<void> _gerarMensalidades() async {
    final confirmou = await AppConfirmDialog.show(
      context,
      title: 'Gerar mensalidades de ${_nomesMeses[_mes - 1]}/$_ano',
      description:
          'Gera 1 mensalidade para cada matrícula ativa cuja vigência cobre este mês. Quem já tem mensalidade gerada pro período não é duplicado.',
      confirmLabel: 'Gerar',
    );
    if (confirmou != true || !mounted) return;

    setState(() => _gerando = true);
    try {
      final resultado = await ref.read(mensalidadesApiProvider).gerar(mes: _mes, ano: _ano);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${resultado.criadas.length} mensalidade(s) gerada(s)'
              '${resultado.totalPuladas > 0 ? ' · ${resultado.totalPuladas} já existiam' : ''}.',
            ),
          ),
        );
      }
      _carregar();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErroApi(e))));
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  Future<void> _abrirAcoes(Mensalidade mensalidade) async {
    final alterou = await showAppDialog<bool>(
      context,
      maxWidth: 420,
      builder: (_) => _AcoesMensalidadeDialog(mensalidade: mensalidade),
    );
    if (alterou == true) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final temFiltroAtivo = _search.isNotEmpty || _statusFiltro != null;
    final anoAtual = DateTime.now().year;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mensalidades', style: AppTypography.displayLarge.copyWith(color: colors.text)),
            const SizedBox(height: AppSpacing.xl),
            // Competência — eixo principal da tela (ver docstring da classe).
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
                AppButton(
                  label: 'Gerar mensalidades do mês',
                  icon: AppIcons.add,
                  loading: _gerando,
                  onPressed: _gerarMensalidades,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppListToolbar(
              search: AppTextField(
                label: 'Buscar',
                hintText: 'Nome do aluno',
                prefixIcon: AppIcons.search,
                controller: _searchController,
                onChanged: _aoBuscar,
              ),
              secondaryActions: [
                SizedBox(
                  width: 190,
                  child: AppSelect<MensalidadeStatus?>(
                    label: 'Status',
                    value: _statusFiltro,
                    options: const [
                      AppSelectOption(value: null, label: 'Todos os status'),
                      AppSelectOption(value: MensalidadeStatus.pendente, label: 'Pendente'),
                      AppSelectOption(value: MensalidadeStatus.paga, label: 'Paga'),
                      AppSelectOption(value: MensalidadeStatus.cancelada, label: 'Cancelada'),
                    ],
                    onChanged: _aoFiltrarStatus,
                  ),
                ),
                const Tooltip(
                  message: 'Ordenação — em breve',
                  child: AppButton(label: 'Ordenar', icon: AppIcons.sort, variant: AppButtonVariant.outline, onPressed: null),
                ),
                const Tooltip(
                  message: 'Exportação — em breve',
                  child: AppButton(label: 'Exportar', icon: AppIcons.download, variant: AppButtonVariant.outline, onPressed: null),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FutureBuilder<PaginatedResult<Mensalidade>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _MensalidadesListaSkeleton();
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: AppIcons.alert,
                    title: 'Não foi possível carregar as mensalidades.',
                    actionLabel: 'Tentar novamente',
                    onAction: _carregar,
                  );
                }
                final resultado = snapshot.data!;
                if (resultado.items.isEmpty) {
                  return EmptyState(
                    icon: AppIcons.finance,
                    title: temFiltroAtivo
                        ? 'Nenhuma mensalidade encontrada'
                        : 'Nenhuma mensalidade em ${_nomesMeses[_mes - 1]}/$_ano',
                    description: temFiltroAtivo
                        ? 'Ajuste a busca ou os filtros e tente de novo.'
                        : 'Gere as mensalidades deste mês a partir das matrículas ativas.',
                    actionLabel: temFiltroAtivo ? 'Limpar filtros' : 'Gerar mensalidades do mês',
                    onAction: temFiltroAtivo ? _limparFiltros : _gerarMensalidades,
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
                            _MensalidadeRow(
                              mensalidade: resultado.items[i],
                              onTap: () => _abrirAcoes(resultado.items[i]),
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

class _MensalidadeRow extends StatelessWidget {
  final Mensalidade mensalidade;
  final VoidCallback onTap;

  const _MensalidadeRow({required this.mensalidade, required this.onTap});

  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (primeira + ultima).toUpperCase();
  }

  String _statusLabel() {
    if (mensalidade.atrasada) return 'Atrasada';
    return switch (mensalidade.status) {
      MensalidadeStatus.pendente => 'Pendente',
      MensalidadeStatus.paga => 'Paga',
      MensalidadeStatus.cancelada => 'Cancelada',
    };
  }

  AppBadgeTone _statusTone() {
    if (mensalidade.atrasada) return AppBadgeTone.error;
    return switch (mensalidade.status) {
      MensalidadeStatus.pendente => AppBadgeTone.warning,
      MensalidadeStatus.paga => AppBadgeTone.success,
      MensalidadeStatus.cancelada => AppBadgeTone.neutral,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      title: mensalidade.alunoNome,
      subtitle: 'Vence em ${dataCurtaFormat.format(mensalidade.dataVencimento)}',
      leadingText: _iniciais(mensalidade.alunoNome),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatoMoeda.format(mensalidade.valorFinal),
            style: AppTypography.mono.copyWith(color: context.colors.text, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppBadge(_statusLabel(), tone: _statusTone()),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _MensalidadesListaSkeleton extends StatelessWidget {
  const _MensalidadesListaSkeleton();

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

enum _AcaoView { menu, pagar, editar, cancelar }

/// Ações rápidas de uma Mensalidade — sem tela de Detalhe própria neste
/// módulo (ver docstring de `MensalidadesScreen`), então trancar/pagar/
/// editar/cancelar/remover vivem num diálogo só, com views internas (não
/// um Dialog por ação) para não empilhar diálogo-sobre-diálogo. Mesmo
/// chassi visual do `AppConfirmDialog` (Dialog + `colors.card` +
/// `AppRadius.lg`), composto com átomos existentes — não é um componente
/// novo do Design System, mesmo padrão de `_CancelarMatriculaDialog` em
/// Matrículas.
class _AcoesMensalidadeDialog extends ConsumerStatefulWidget {
  const _AcoesMensalidadeDialog({required this.mensalidade});

  final Mensalidade mensalidade;

  @override
  ConsumerState<_AcoesMensalidadeDialog> createState() => _AcoesMensalidadeDialogState();
}

class _AcoesMensalidadeDialogState extends ConsumerState<_AcoesMensalidadeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descontoController = TextEditingController();
  final _multaController = TextEditingController();
  final _motivoController = TextEditingController();

  _AcaoView _view = _AcaoView.menu;
  FormaPagamento? _formaPagamento;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _descontoController.text = widget.mensalidade.desconto.toStringAsFixed(2).replaceAll('.', ',');
    _multaController.text = widget.mensalidade.multa.toStringAsFixed(2).replaceAll('.', ',');
  }

  @override
  void dispose() {
    _descontoController.dispose();
    _multaController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _pagar() async {
    setState(() => _erro = null);
    if (_formaPagamento == null) {
      setState(() => _erro = 'Selecione a forma de pagamento');
      return;
    }
    setState(() => _salvando = true);
    try {
      await ref
          .read(mensalidadesApiProvider)
          .marcarPaga(widget.mensalidade.id, formaPagamento: _formaPagamento!);
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _editar() async {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await ref
          .read(mensalidadesApiProvider)
          .update(widget.mensalidade.id, {
            'desconto': double.parse(_descontoController.text.trim().replaceAll(',', '.')),
            'multa': double.parse(_multaController.text.trim().replaceAll(',', '.')),
          });
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _cancelar() async {
    setState(() => _erro = null);
    setState(() => _salvando = true);
    try {
      await ref
          .read(mensalidadesApiProvider)
          .cancelar(
            widget.mensalidade.id,
            motivo: _motivoController.text.trim().isEmpty ? null : _motivoController.text.trim(),
          );
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
      title: 'Remover mensalidade',
      description:
          'Reservado a corrigir uma cobrança gerada por engano — some da lista, mas nada é apagado permanentemente. Para um cancelamento de verdade, use Cancelar em vez disto.',
      confirmLabel: 'Remover',
    );
    if (confirmou != true || !mounted) return;

    setState(() => _salvando = true);
    try {
      await ref.read(mensalidadesApiProvider).remove(widget.mensalidade.id);
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _erro = mensagemErroApi(e));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mensalidade = widget.mensalidade;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(mensalidade.alunoNome, style: AppTypography.titleLarge.copyWith(color: colors.text)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Vencimento ${dataCurtaFormat.format(mensalidade.dataVencimento)} · ${_formatoMoeda.format(mensalidade.valorFinal)}',
          style: AppTypography.bodyMedium.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_view == _AcaoView.menu) ..._menu(mensalidade),
        if (_view == _AcaoView.pagar) ..._formPagar(),
        if (_view == _AcaoView.editar) ..._formEditar(),
        if (_view == _AcaoView.cancelar) ..._formCancelar(),
      ],
    );
  }

  List<Widget> _menu(Mensalidade mensalidade) {
    final pendente = mensalidade.status == MensalidadeStatus.pendente;
    return [
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          if (pendente)
            AppButton(
              label: 'Marcar como paga',
              icon: AppIcons.circleCheck,
              onPressed: () => setState(() => _view = _AcaoView.pagar),
            ),
          if (pendente)
            AppButton(
              label: 'Editar',
              icon: AppIcons.edit,
              variant: AppButtonVariant.secondary,
              onPressed: () => setState(() => _view = _AcaoView.editar),
            ),
          if (pendente)
            AppButton(
              label: 'Cancelar',
              icon: AppIcons.circleX,
              variant: AppButtonVariant.secondary,
              onPressed: () => setState(() => _view = _AcaoView.cancelar),
            ),
          if (mensalidade.status != MensalidadeStatus.paga)
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

  List<Widget> _formPagar() {
    return [
      AppSelect<FormaPagamento?>(
        label: 'Forma de pagamento',
        value: _formaPagamento,
        options: const [
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
      _botoesVoltarConfirmar(label: 'Confirmar pagamento', onConfirmar: _pagar),
    ];
  }

  List<Widget> _formEditar() {
    return [
      Form(
        key: _formKey,
        child: AppFormRow(
          children: [
            AppTextField(
              label: 'Desconto',
              controller: _descontoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final numero = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                if (numero == null || numero < 0) return 'Informe um valor válido';
                return null;
              },
            ),
            AppTextField(
              label: 'Multa',
              controller: _multaController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final numero = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                if (numero == null || numero < 0) return 'Informe um valor válido';
                return null;
              },
            ),
          ],
        ),
      ),
      if (_erro != null) ...[
        const SizedBox(height: AppSpacing.md),
        AppFormErrorBanner(_erro!),
      ],
      const SizedBox(height: AppSpacing.xl),
      _botoesVoltarConfirmar(label: 'Salvar', onConfirmar: _editar),
    ];
  }

  List<Widget> _formCancelar() {
    return [
      AppTextField(label: 'Motivo (opcional)', controller: _motivoController, maxLines: 2),
      if (_erro != null) ...[
        const SizedBox(height: AppSpacing.md),
        AppFormErrorBanner(_erro!),
      ],
      const SizedBox(height: AppSpacing.xl),
      _botoesVoltarConfirmar(label: 'Confirmar cancelamento', onConfirmar: _cancelar),
    ];
  }

  Widget _botoesVoltarConfirmar({required String label, required VoidCallback onConfirmar}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AppButton(
          label: 'Voltar',
          variant: AppButtonVariant.secondary,
          onPressed: _salvando ? null : () => setState(() => _view = _AcaoView.menu),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppButton(label: label, loading: _salvando, onPressed: onConfirmar),
      ],
    );
  }
}

