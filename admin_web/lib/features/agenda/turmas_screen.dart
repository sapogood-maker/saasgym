import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

/// Lista de turmas — Módulo 4 (MS3), mesmo padrão consolidado por
/// Planos/Matrículas: `AppListToolbar` + `AppListTile`s dentro de um
/// `AppCard` + `AppPagination`. Nenhum componente novo do Design System.
class TurmasScreen extends ConsumerStatefulWidget {
  const TurmasScreen({super.key});

  @override
  ConsumerState<TurmasScreen> createState() => _TurmasScreenState();
}

class _TurmasScreenState extends ConsumerState<TurmasScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  String _search = '';
  UserStatus? _statusFiltro;
  int _pagina = 1;
  static const _tamanhoPagina = 20;

  Future<PaginatedResult<Turma>>? _future;

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
          .read(turmasApiProvider)
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

  Future<void> _novaTurma() async {
    final criada = await context.push<bool>('/agenda/turmas/novo');
    if (criada == true) _carregar();
  }

  Future<void> _abrirDetalhe(Turma turma) async {
    final alterado = await context.push<bool>('/agenda/turmas/${turma.id}');
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
            Text('Turmas', style: AppTypography.displayLarge.copyWith(color: colors.text)),
            const SizedBox(height: AppSpacing.xl),
            AppListToolbar(
              search: AppTextField(
                label: 'Buscar',
                hintText: 'Nome da turma',
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
              primaryAction: AppButton(label: 'Nova turma', icon: AppIcons.add, onPressed: _novaTurma),
            ),
            const SizedBox(height: AppSpacing.xl),
            FutureBuilder<PaginatedResult<Turma>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _TurmasListaSkeleton();
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: AppIcons.alert,
                    title: 'Não foi possível carregar as turmas.',
                    actionLabel: 'Tentar novamente',
                    onAction: _carregar,
                  );
                }
                final resultado = snapshot.data!;
                if (resultado.items.isEmpty) {
                  return EmptyState(
                    icon: AppIcons.turmas,
                    title: temFiltroAtivo ? 'Nenhuma turma encontrada' : 'Nenhuma turma cadastrada',
                    description: temFiltroAtivo
                        ? 'Ajuste a busca ou os filtros e tente de novo.'
                        : 'Cadastre a primeira turma para começar a organizar os horários.',
                    actionLabel: temFiltroAtivo ? 'Limpar filtros' : 'Cadastrar turma',
                    onAction: temFiltroAtivo ? _limparFiltros : _novaTurma,
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
                            _TurmaRow(turma: resultado.items[i], onTap: () => _abrirDetalhe(resultado.items[i])),
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

class _TurmaRow extends StatelessWidget {
  final Turma turma;
  final VoidCallback onTap;

  const _TurmaRow({required this.turma, required this.onTap});

  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (primeira + ultima).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ativo = turma.status == UserStatus.ativo;
    final capacidade = turma.capacidadeMaxima != null ? 'até ${turma.capacidadeMaxima} alunos' : 'sem limite';

    return AppListTile(
      title: turma.nome,
      subtitle: '${turma.modalidadeNome} · ${turma.professorNome} · $capacidade',
      leadingText: _iniciais(turma.nome),
      trailing: AppBadge(
        ativo ? 'Ativa' : 'Inativa',
        tone: ativo ? AppBadgeTone.success : AppBadgeTone.neutral,
      ),
      onTap: onTap,
    );
  }
}

class _TurmasListaSkeleton extends StatelessWidget {
  const _TurmasListaSkeleton();

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
