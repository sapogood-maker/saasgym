import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';

/// Lista de modalidades — Módulo 4 (MS3). Cadastro simples (nome + cor),
/// gerenciado inteiramente via diálogo (`_NovaModalidadeDialog`/
/// `_AcoesModalidadeDialog`) — sem tela de Detalhe própria nem rotas
/// `/novo`/`/editar`: só 2 campos editáveis, o mesmo raciocínio já usado
/// pra `_NovoLancamentoDialog`/`_AcoesLancamentoDialog` no Caixa (docs/15,
/// seção "Diálogo com campos").
///
/// Mesmo padrão consolidado de lista (`AppListToolbar`+`AppListTile`s
/// dentro de `AppCard`+`AppPagination`) — nenhum componente novo do Design
/// System.
class ModalidadesScreen extends ConsumerStatefulWidget {
  const ModalidadesScreen({super.key});

  @override
  ConsumerState<ModalidadesScreen> createState() => _ModalidadesScreenState();
}

class _ModalidadesScreenState extends ConsumerState<ModalidadesScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  String _search = '';
  UserStatus? _statusFiltro;
  int _pagina = 1;
  static const _tamanhoPagina = 20;

  Future<PaginatedResult<Modalidade>>? _future;

  @override
  void initState() {
    super.initState();
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
          .read(modalidadesApiProvider)
          .list(search: _search, status: _statusFiltro, page: _pagina, pageSize: _tamanhoPagina);
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

  void _aoFiltrarStatus(UserStatus? status) {
    setState(() {
      _statusFiltro = status;
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

  Future<void> _novaModalidade() async {
    final criada = await showAppDialog<bool>(
      context,
      maxWidth: 420,
      builder: (_) => const _NovaModalidadeDialog(),
    );
    if (criada == true) _carregar();
  }

  Future<void> _abrirAcoes(Modalidade modalidade) async {
    final alterou = await showAppDialog<bool>(
      context,
      maxWidth: 420,
      builder: (_) => _AcoesModalidadeDialog(modalidade: modalidade),
    );
    if (alterou == true) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final temFiltroAtivo = _search.isNotEmpty || _statusFiltro != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modalidades', style: AppTypography.displayLarge.copyWith(color: colors.text)),
            const SizedBox(height: AppSpacing.xl),
            AppListToolbar(
              search: AppTextField(
                label: 'Buscar',
                hintText: 'Nome da modalidade',
                prefixIcon: AppIcons.search,
                controller: _searchController,
                onChanged: _aoBuscar,
              ),
              secondaryActions: [
                SizedBox(
                  width: 170,
                  child: AppSelect<UserStatus?>(
                    label: 'Status',
                    value: _statusFiltro,
                    options: const [
                      AppSelectOption(value: null, label: 'Todos os status'),
                      AppSelectOption(value: UserStatus.ativo, label: 'Ativas'),
                      AppSelectOption(value: UserStatus.inativo, label: 'Inativas'),
                    ],
                    onChanged: _aoFiltrarStatus,
                  ),
                ),
              ],
              primaryAction: AppButton(
                label: 'Nova modalidade',
                icon: AppIcons.add,
                onPressed: _novaModalidade,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FutureBuilder<PaginatedResult<Modalidade>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _ModalidadesListaSkeleton();
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: AppIcons.alert,
                    title: 'Não foi possível carregar as modalidades.',
                    actionLabel: 'Tentar novamente',
                    onAction: _carregar,
                  );
                }
                final resultado = snapshot.data!;
                if (resultado.items.isEmpty) {
                  return EmptyState(
                    icon: AppIcons.modalidade,
                    title: temFiltroAtivo
                        ? 'Nenhuma modalidade encontrada'
                        : 'Nenhuma modalidade cadastrada',
                    description: temFiltroAtivo
                        ? 'Ajuste a busca ou os filtros e tente de novo.'
                        : 'Cadastre a primeira modalidade para começar a criar turmas.',
                    actionLabel: temFiltroAtivo ? 'Limpar filtros' : 'Nova modalidade',
                    onAction: temFiltroAtivo ? _limparFiltros : _novaModalidade,
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
                            _ModalidadeRow(
                              modalidade: resultado.items[i],
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

Color? _corDeHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final limpo = hex.replaceFirst('#', '');
  final valor = int.tryParse(limpo, radix: 16);
  if (valor == null) return null;
  return Color(0xFF000000 | valor);
}

class _ModalidadeRow extends StatelessWidget {
  final Modalidade modalidade;
  final VoidCallback onTap;

  const _ModalidadeRow({required this.modalidade, required this.onTap});

  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (primeira + ultima).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ativo = modalidade.status == UserStatus.ativo;
    final cor = _corDeHex(modalidade.cor);

    return AppListTile(
      title: modalidade.nome,
      subtitle: modalidade.cor,
      leadingText: _iniciais(modalidade.nome),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cor != null) ...[
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          AppBadge(
            ativo ? 'Ativa' : 'Inativa',
            tone: ativo ? AppBadgeTone.success : AppBadgeTone.neutral,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _ModalidadesListaSkeleton extends StatelessWidget {
  const _ModalidadesListaSkeleton();

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

/// Criação de modalidade — só 2 campos (nome, cor), diálogo em vez de
/// rota própria (mesmo padrão de `_NovoLancamentoDialog`).
class _NovaModalidadeDialog extends ConsumerStatefulWidget {
  const _NovaModalidadeDialog();

  @override
  ConsumerState<_NovaModalidadeDialog> createState() => _NovaModalidadeDialogState();
}

class _NovaModalidadeDialogState extends ConsumerState<_NovaModalidadeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _corController = TextEditingController();

  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _nomeController.dispose();
    _corController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await ref.read(modalidadesApiProvider).create({
        'nome': _nomeController.text.trim(),
        if (_corController.text.trim().isNotEmpty) 'cor': _corController.text.trim(),
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

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nova modalidade', style: AppTypography.titleLarge.copyWith(color: colors.text)),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'Nome',
            controller: _nomeController,
            validator: (v) => (v == null || v.trim().length < 2) ? 'Informe o nome' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Cor (opcional)',
            hintText: '#3B82F6',
            controller: _corController,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final valido = RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v.trim());
              return valido ? null : 'Formato inválido — use #RRGGBB';
            },
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
    );
  }
}

enum _AcaoView { menu, editar }

/// Ações rápidas de uma modalidade — editar, ativar/inativar, remover.
/// Mesmo chassi de `_AcoesLancamentoDialog`/`_AcoesMensalidadeDialog`.
class _AcoesModalidadeDialog extends ConsumerStatefulWidget {
  const _AcoesModalidadeDialog({required this.modalidade});

  final Modalidade modalidade;

  @override
  ConsumerState<_AcoesModalidadeDialog> createState() => _AcoesModalidadeDialogState();
}

class _AcoesModalidadeDialogState extends ConsumerState<_AcoesModalidadeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _corController;

  _AcaoView _view = _AcaoView.menu;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.modalidade.nome);
    _corController = TextEditingController(text: widget.modalidade.cor ?? '');
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _corController.dispose();
    super.dispose();
  }

  Future<void> _salvarEdicao() async {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await ref.read(modalidadesApiProvider).update(widget.modalidade.id, {
        'nome': _nomeController.text.trim(),
        'cor': _corController.text.trim().isEmpty ? null : _corController.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _alternarStatus() async {
    setState(() => _salvando = true);
    try {
      final novoStatus = widget.modalidade.status == UserStatus.ativo
          ? UserStatus.inativo
          : UserStatus.ativo;
      await ref.read(modalidadesApiProvider).updateStatus(widget.modalidade.id, novoStatus);
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
      title: 'Remover modalidade',
      description:
          'Remover ${widget.modalidade.nome}? O cadastro fica inativo e preservado (nada é apagado permanentemente).',
      confirmLabel: 'Remover',
    );
    if (confirmou != true || !mounted) return;

    setState(() => _salvando = true);
    try {
      await ref.read(modalidadesApiProvider).remove(widget.modalidade.id);
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.modalidade.nome, style: AppTypography.titleLarge.copyWith(color: colors.text)),
        const SizedBox(height: AppSpacing.lg),
        if (_view == _AcaoView.menu) ..._menu(),
        if (_view == _AcaoView.editar) ..._formEditar(),
      ],
    );
  }

  List<Widget> _menu() {
    final ativo = widget.modalidade.status == UserStatus.ativo;
    return [
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          AppButton(
            label: 'Editar',
            icon: AppIcons.edit,
            onPressed: _salvando ? null : () => setState(() => _view = _AcaoView.editar),
          ),
          AppButton(
            label: ativo ? 'Inativar' : 'Reativar',
            icon: ativo ? AppIcons.block : AppIcons.circleCheck,
            variant: AppButtonVariant.secondary,
            loading: _salvando,
            onPressed: _alternarStatus,
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
      if (_erro != null) ...[
        const SizedBox(height: AppSpacing.md),
        AppFormErrorBanner(_erro!),
      ],
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
            AppTextField(
              label: 'Nome',
              controller: _nomeController,
              validator: (v) => (v == null || v.trim().length < 2) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Cor (opcional)',
              hintText: '#3B82F6',
              controller: _corController,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final valido = RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v.trim());
                return valido ? null : 'Formato inválido — use #RRGGBB';
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

