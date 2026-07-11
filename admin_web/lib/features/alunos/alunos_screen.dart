import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

/// Lista de alunos — primeira tela de produto construída inteiramente
/// sobre o Design System (Sprint 2, MS3). Referência de composição para
/// toda lista futura do sistema (Professores, Planos, Turmas...):
/// `AppListToolbar` (busca + filtros + ação principal) + `AppListTile`s
/// dentro de um `AppCard` + `AppPagination`, com skeleton/erro/vazio
/// tratados explicitamente — nunca uma tela "quebrada".
class AlunosScreen extends ConsumerStatefulWidget {
  const AlunosScreen({super.key});

  @override
  ConsumerState<AlunosScreen> createState() => _AlunosScreenState();
}

class _AlunosScreenState extends ConsumerState<AlunosScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  String _search = '';
  UserStatus? _statusFiltro;
  int _pagina = 1;
  static const _tamanhoPagina = 20;

  Future<PaginatedResult<Aluno>>? _future;

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
          .read(alunosApiProvider)
          .list(search: _search, status: _statusFiltro, page: _pagina, pageSize: _tamanhoPagina);
    });
  }

  // Debounce de 400ms: busca "extremamente rápida" pro usuário não é o
  // mesmo que uma requisição por tecla — é resposta ágil sem sobrecarregar
  // a API a cada caractere digitado.
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

  Future<void> _novoAluno() async {
    final criado = await context.push<bool>('/alunos/novo');
    if (criado == true) _carregar();
  }

  Future<void> _abrirDetalhe(Aluno aluno) async {
    final alterado = await context.push<bool>('/alunos/${aluno.id}');
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
            Text('Alunos', style: AppTypography.displayLarge.copyWith(color: colors.text)),
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
                // Sem backend de ordenação/exportação ainda — visíveis e
                // inertes, mesmo princípio dos itens desabilitados da
                // sidebar (Agenda/Financeiro): a ação existe na intenção,
                // não finge funcionar.
                const Tooltip(
                  message: 'Ordenação — em breve',
                  child: AppButton(label: 'Ordenar', icon: AppIcons.sort, variant: AppButtonVariant.outline, onPressed: null),
                ),
                const Tooltip(
                  message: 'Exportação — em breve',
                  child: AppButton(label: 'Exportar', icon: AppIcons.download, variant: AppButtonVariant.outline, onPressed: null),
                ),
              ],
              primaryAction: AppButton(label: 'Novo aluno', icon: AppIcons.add, onPressed: _novoAluno),
            ),
            const SizedBox(height: AppSpacing.xl),
            FutureBuilder<PaginatedResult<Aluno>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _AlunosListaSkeleton();
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: AppIcons.alert,
                    title: 'Não foi possível carregar os alunos.',
                    actionLabel: 'Tentar novamente',
                    onAction: _carregar,
                  );
                }
                final resultado = snapshot.data!;
                if (resultado.items.isEmpty) {
                  return EmptyState(
                    icon: AppIcons.students,
                    title: temFiltroAtivo ? 'Nenhum aluno encontrado' : 'Nenhum aluno cadastrado',
                    description: temFiltroAtivo
                        ? 'Ajuste a busca ou os filtros e tente de novo.'
                        : 'Cadastre o primeiro aluno para começar a usar o SaaSGym.',
                    actionLabel: temFiltroAtivo ? 'Limpar filtros' : 'Cadastrar aluno',
                    onAction: temFiltroAtivo ? _limparFiltros : _novoAluno,
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
                            _AlunoRow(aluno: resultado.items[i], onTap: () => _abrirDetalhe(resultado.items[i])),
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

class _AlunoRow extends StatelessWidget {
  final Aluno aluno;
  final VoidCallback onTap;

  const _AlunoRow({required this.aluno, required this.onTap});

  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (primeira + ultima).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      title: aluno.nome,
      subtitle: '${aluno.cpf} · ${aluno.telefone}',
      leadingText: _iniciais(aluno.nome),
      trailing: AppBadge(
        aluno.status == UserStatus.ativo ? 'Ativo' : 'Inativo',
        tone: aluno.status == UserStatus.ativo ? AppBadgeTone.success : AppBadgeTone.neutral,
      ),
      onTap: onTap,
    );
  }
}

class _AlunosListaSkeleton extends StatelessWidget {
  const _AlunosListaSkeleton();

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
