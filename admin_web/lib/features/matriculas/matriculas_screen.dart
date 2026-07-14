import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

final _formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

/// Lista de matrículas — Módulo 2 (MS3), mesmo padrão consolidado por
/// Alunos/Professores/Planos: `AppListToolbar` + `AppListTile`s dentro de
/// um `AppCard` + `AppPagination`. Nenhum componente novo do Design System
/// foi necessário.
///
/// "Nova matrícula" leva ao Formulário (MS4); tocar numa linha leva ao
/// Detalhe (MS5), onde vivem as transições de ciclo de vida.
class MatriculasScreen extends ConsumerStatefulWidget {
  const MatriculasScreen({super.key});

  @override
  ConsumerState<MatriculasScreen> createState() => _MatriculasScreenState();
}

class _MatriculasScreenState extends ConsumerState<MatriculasScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  String _search = '';
  MatriculaStatus? _statusFiltro;
  int _pagina = 1;
  static const _tamanhoPagina = 20;

  Future<PaginatedResult<Matricula>>? _future;

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
          .read(matriculasApiProvider)
          .listMatriculas(
            search: _search,
            status: _statusFiltro,
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

  void _aoFiltrarStatus(MatriculaStatus? status) {
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

  Future<void> _novaMatricula() async {
    final criada = await context.push<bool>('/matriculas/novo');
    if (criada == true) _carregar();
  }

  Future<void> _abrirDetalhe(Matricula matricula) async {
    final alterado = await context.push<bool>('/matriculas/${matricula.id}');
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
            Text('Matrículas', style: AppTypography.displayLarge.copyWith(color: colors.text)),
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
                  child: AppSelect<MatriculaStatus?>(
                    label: 'Status',
                    value: _statusFiltro,
                    options: const [
                      AppSelectOption(value: null, label: 'Todos os status'),
                      AppSelectOption(value: MatriculaStatus.ativa, label: 'Ativas'),
                      AppSelectOption(value: MatriculaStatus.trancada, label: 'Trancadas'),
                      AppSelectOption(value: MatriculaStatus.cancelada, label: 'Canceladas'),
                      AppSelectOption(value: MatriculaStatus.encerrada, label: 'Encerradas'),
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
              primaryAction: AppButton(label: 'Nova matrícula', icon: AppIcons.add, onPressed: _novaMatricula),
            ),
            const SizedBox(height: AppSpacing.xl),
            FutureBuilder<PaginatedResult<Matricula>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _MatriculasListaSkeleton();
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: AppIcons.alert,
                    title: 'Não foi possível carregar as matrículas.',
                    actionLabel: 'Tentar novamente',
                    onAction: _carregar,
                  );
                }
                final resultado = snapshot.data!;
                if (resultado.items.isEmpty) {
                  return EmptyState(
                    icon: AppIcons.enrollment,
                    title: temFiltroAtivo ? 'Nenhuma matrícula encontrada' : 'Nenhuma matrícula cadastrada',
                    description: temFiltroAtivo
                        ? 'Ajuste a busca ou os filtros e tente de novo.'
                        : 'Matricule o primeiro aluno num plano para começar.',
                    actionLabel: temFiltroAtivo ? 'Limpar filtros' : 'Nova matrícula',
                    onAction: temFiltroAtivo ? _limparFiltros : _novaMatricula,
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
                            _MatriculaRow(
                              matricula: resultado.items[i],
                              onTap: () => _abrirDetalhe(resultado.items[i]),
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

class _MatriculaRow extends StatelessWidget {
  final Matricula matricula;
  final VoidCallback onTap;

  const _MatriculaRow({required this.matricula, required this.onTap});

  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (primeira + ultima).toUpperCase();
  }

  String _statusLabel(MatriculaStatus status) => switch (status) {
    MatriculaStatus.ativa => 'Ativa',
    MatriculaStatus.trancada => 'Trancada',
    MatriculaStatus.cancelada => 'Cancelada',
    MatriculaStatus.encerrada => 'Encerrada',
  };

  AppBadgeTone _statusTone(MatriculaStatus status) => switch (status) {
    MatriculaStatus.ativa => AppBadgeTone.success,
    MatriculaStatus.trancada => AppBadgeTone.warning,
    MatriculaStatus.cancelada => AppBadgeTone.error,
    MatriculaStatus.encerrada => AppBadgeTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      title: matricula.alunoNome,
      subtitle: '${matricula.planoNome} · vence dia ${matricula.diaVencimento} · até ${dataCurtaFormat.format(matricula.dataFim)}',
      leadingText: _iniciais(matricula.alunoNome),
      // Empilhado, não lado a lado: mesmo raciocínio já usado em
      // PlanosScreen (um Row valor+badge não cabe ao lado de um
      // AppListTile em largura de celular).
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatoMoeda.format(matricula.valor),
            style: AppTypography.mono.copyWith(color: context.colors.text, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppBadge(_statusLabel(matricula.status), tone: _statusTone(matricula.status)),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _MatriculasListaSkeleton extends StatelessWidget {
  const _MatriculasListaSkeleton();

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
