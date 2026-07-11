import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

/// Lista de professores — Sprint 3, reescrita 1:1 do padrão consolidado
/// pelo módulo de Alunos (Sprint 2): `AppListToolbar` + `AppListTile`s
/// dentro de um `AppCard` + `AppPagination`, skeleton/erro/vazio tratados
/// explicitamente. Nenhum componente novo do Design System foi necessário
/// para esta tela.
class ProfessoresScreen extends ConsumerStatefulWidget {
  const ProfessoresScreen({super.key});

  @override
  ConsumerState<ProfessoresScreen> createState() => _ProfessoresScreenState();
}

class _ProfessoresScreenState extends ConsumerState<ProfessoresScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  String _search = '';
  UserStatus? _statusFiltro;
  int _pagina = 1;
  static const _tamanhoPagina = 20;

  Future<PaginatedResult<Professor>>? _future;

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
          .read(professoresApiProvider)
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

  Future<void> _novoProfessor() async {
    final criado = await context.push<bool>('/professores/novo');
    if (criado == true) _carregar();
  }

  Future<void> _abrirDetalhe(Professor professor) async {
    final alterado = await context.push<bool>('/professores/${professor.id}');
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
            Text('Professores', style: AppTypography.displayLarge.copyWith(color: colors.text)),
            const SizedBox(height: AppSpacing.xl),
            AppListToolbar(
              search: AppTextField(
                label: 'Buscar',
                hintText: 'Nome, CPF ou telefone',
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
              primaryAction: AppButton(label: 'Novo professor', icon: AppIcons.add, onPressed: _novoProfessor),
            ),
            const SizedBox(height: AppSpacing.xl),
            FutureBuilder<PaginatedResult<Professor>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _ProfessoresListaSkeleton();
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: AppIcons.alert,
                    title: 'Não foi possível carregar os professores.',
                    actionLabel: 'Tentar novamente',
                    onAction: _carregar,
                  );
                }
                final resultado = snapshot.data!;
                if (resultado.items.isEmpty) {
                  return EmptyState(
                    icon: AppIcons.teachers,
                    title: temFiltroAtivo ? 'Nenhum professor encontrado' : 'Nenhum professor cadastrado',
                    description: temFiltroAtivo
                        ? 'Ajuste a busca ou os filtros e tente de novo.'
                        : 'Cadastre o primeiro professor para começar a montar sua equipe.',
                    actionLabel: temFiltroAtivo ? 'Limpar filtros' : 'Cadastrar professor',
                    onAction: temFiltroAtivo ? _limparFiltros : _novoProfessor,
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
                            _ProfessorRow(professor: resultado.items[i], onTap: () => _abrirDetalhe(resultado.items[i])),
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

class _ProfessorRow extends StatelessWidget {
  final Professor professor;
  final VoidCallback onTap;

  const _ProfessorRow({required this.professor, required this.onTap});

  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (primeira + ultima).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final subtitulo = professor.especialidade != null
        ? '${professor.cpf} · ${professor.telefone} · ${professor.especialidade}'
        : '${professor.cpf} · ${professor.telefone}';

    return AppListTile(
      title: professor.nome,
      subtitle: subtitulo,
      leadingText: _iniciais(professor.nome),
      trailing: AppBadge(
        professor.status == UserStatus.ativo ? 'Ativo' : 'Inativo',
        tone: professor.status == UserStatus.ativo ? AppBadgeTone.success : AppBadgeTone.neutral,
      ),
      onTap: onTap,
    );
  }
}

class _ProfessoresListaSkeleton extends StatelessWidget {
  const _ProfessoresListaSkeleton();

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
