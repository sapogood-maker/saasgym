import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

final _formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

/// Lista de planos — Módulo 1, mesmo padrão consolidado por Alunos
/// (Sprint 2)/Professores (Sprint 3): `AppListToolbar` + `AppListTile`s
/// dentro de um `AppCard` + `AppPagination`. Nenhum componente novo do
/// Design System foi necessário.
///
/// "Novo plano" e o toque nas linhas (`PlanoDetailScreen`) já estão
/// habilitados — Módulo 1 completo a partir do MS5.
class PlanosScreen extends ConsumerStatefulWidget {
  const PlanosScreen({super.key});

  @override
  ConsumerState<PlanosScreen> createState() => _PlanosScreenState();
}

class _PlanosScreenState extends ConsumerState<PlanosScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  String _search = '';
  UserStatus? _statusFiltro;
  int _pagina = 1;
  static const _tamanhoPagina = 20;

  Future<PaginatedResult<Plano>>? _future;

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
          .read(planosApiProvider)
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

  Future<void> _novoPlano() async {
    final criado = await context.push<bool>('/planos/novo');
    if (criado == true) _carregar();
  }

  Future<void> _abrirDetalhe(Plano plano) async {
    final alterado = await context.push<bool>('/planos/${plano.id}');
    if (alterado == true) _carregar();
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
            Text('Planos', style: AppTypography.displayLarge.copyWith(color: colors.text)),
            const SizedBox(height: AppSpacing.xl),
            AppListToolbar(
              search: AppTextField(
                label: 'Buscar',
                hintText: 'Nome do plano',
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
                      AppSelectOption(value: UserStatus.ativo, label: 'Ativos'),
                      AppSelectOption(value: UserStatus.inativo, label: 'Inativos'),
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
              primaryAction: AppButton(label: 'Novo plano', icon: AppIcons.add, onPressed: _novoPlano),
            ),
            const SizedBox(height: AppSpacing.xl),
            FutureBuilder<PaginatedResult<Plano>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _PlanosListaSkeleton();
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: AppIcons.alert,
                    title: 'Não foi possível carregar os planos.',
                    actionLabel: 'Tentar novamente',
                    onAction: _carregar,
                  );
                }
                final resultado = snapshot.data!;
                if (resultado.items.isEmpty) {
                  return EmptyState(
                    icon: AppIcons.plans,
                    title: temFiltroAtivo ? 'Nenhum plano encontrado' : 'Nenhum plano cadastrado',
                    description: temFiltroAtivo
                        ? 'Ajuste a busca ou os filtros e tente de novo.'
                        : 'Cadastre o primeiro plano para começar a vender mensalidades.',
                    actionLabel: temFiltroAtivo ? 'Limpar filtros' : 'Cadastrar plano',
                    onAction: temFiltroAtivo ? _limparFiltros : _novoPlano,
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
                            _PlanoRow(plano: resultado.items[i], onTap: () => _abrirDetalhe(resultado.items[i])),
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

class _PlanoRow extends StatelessWidget {
  final Plano plano;
  final VoidCallback onTap;

  const _PlanoRow({required this.plano, required this.onTap});

  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (primeira + ultima).toUpperCase();
  }

  String _periodicidadeLabel(Periodicidade periodicidade) {
    switch (periodicidade) {
      case Periodicidade.mensal:
        return 'Mensal';
      case Periodicidade.trimestral:
        return 'Trimestral';
      case Periodicidade.semestral:
        return 'Semestral';
      case Periodicidade.anual:
        return 'Anual';
    }
  }

  @override
  Widget build(BuildContext context) {
    final aulas = plano.quantidadeAulas != null ? '${plano.quantidadeAulas} aulas' : 'Aulas ilimitadas';

    return AppListTile(
      title: plano.nome,
      subtitle: '${_periodicidadeLabel(plano.periodicidade)} · $aulas',
      leadingText: _iniciais(plano.nome),
      // Empilhado, não lado a lado: um Row (valor + badge) não cabe ao
      // lado de um AppListTile em largura de celular — mesmo raciocínio
      // do bug já corrigido em AppPagination.
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_formatoMoeda.format(plano.valor), style: AppTypography.mono.copyWith(color: context.colors.text, fontSize: 13)),
          const SizedBox(height: AppSpacing.xs),
          AppBadge(
            plano.status == UserStatus.ativo ? 'Ativo' : 'Inativo',
            tone: plano.status == UserStatus.ativo ? AppBadgeTone.success : AppBadgeTone.neutral,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _PlanosListaSkeleton extends StatelessWidget {
  const _PlanosListaSkeleton();

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
