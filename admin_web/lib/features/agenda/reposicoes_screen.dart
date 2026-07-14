import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';

/// Sprint 6 (Agenda Avançada) MS4 — tela de topo (docs/21, decisão 11),
/// não embutida em Turma/Aluno: a gestão de solicitações cruza alunos e
/// turmas, mesmo critério já usado pra `CalendarScreen` (MS7). Criar uma
/// solicitação é sempre contextual (a partir da Frequência de uma aula, no
/// Calendário) — esta tela só lista/aprova/rejeita, sem `AppListToolbar`
/// (sem campo de busca por nome no backend ainda, mesmo critério já usado
/// pela própria `CalendarScreen`, que também não usa o toolbar padrão).
class ReposicoesScreen extends ConsumerStatefulWidget {
  const ReposicoesScreen({super.key});

  @override
  ConsumerState<ReposicoesScreen> createState() => _ReposicoesScreenState();
}

class _ReposicoesScreenState extends ConsumerState<ReposicoesScreen> {
  Future<PaginatedResult<SolicitacaoReposicao>>? _future;
  SolicitacaoReposicaoStatus? _statusFiltro = SolicitacaoReposicaoStatus.pendente;
  int _pagina = 1;
  static const _tamanhoPagina = 20;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _future = ref.read(solicitacoesReposicaoApiProvider).list(
            status: _statusFiltro,
            page: _pagina,
            pageSize: _tamanhoPagina,
          );
    });
  }

  void _aoFiltrarStatus(SolicitacaoReposicaoStatus? status) {
    setState(() {
      _statusFiltro = status;
      _pagina = 1;
    });
    _carregar();
  }

  void _irParaPagina(int pagina) {
    setState(() => _pagina = pagina);
    _carregar();
  }

  Future<void> _aprovar(SolicitacaoReposicao solicitacao) async {
    final aprovou = await showDialog<bool>(
      context: context,
      builder: (_) => _AprovarSolicitacaoDialog(solicitacao: solicitacao),
    );
    if (aprovou == true) _carregar();
  }

  Future<void> _rejeitar(SolicitacaoReposicao solicitacao) async {
    final rejeitou = await showDialog<bool>(
      context: context,
      builder: (_) => _RejeitarSolicitacaoDialog(solicitacao: solicitacao),
    );
    if (rejeitou == true) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reposições', style: AppTypography.displayLarge.copyWith(color: colors.text)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Solicitações são criadas a partir da Frequência de uma aula, no Calendário.',
              style: AppTypography.bodyMedium.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 220,
              child: AppSelect<SolicitacaoReposicaoStatus?>(
                label: 'Status',
                value: _statusFiltro,
                options: const [
                  AppSelectOption(value: null, label: 'Todos os status'),
                  AppSelectOption(value: SolicitacaoReposicaoStatus.pendente, label: 'Pendente'),
                  AppSelectOption(value: SolicitacaoReposicaoStatus.aprovada, label: 'Aprovada'),
                  AppSelectOption(value: SolicitacaoReposicaoStatus.rejeitada, label: 'Rejeitada'),
                ],
                onChanged: _aoFiltrarStatus,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FutureBuilder<PaginatedResult<SolicitacaoReposicao>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LoadingSkeleton(width: double.infinity, height: 64),
                      SizedBox(height: AppSpacing.sm),
                      LoadingSkeleton(width: double.infinity, height: 64),
                    ],
                  );
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: AppIcons.alert,
                    title: 'Não foi possível carregar as solicitações.',
                    actionLabel: 'Tentar novamente',
                    onAction: _carregar,
                  );
                }
                final resultado = snapshot.data!;
                if (resultado.items.isEmpty) {
                  return const EmptyState(
                    icon: AppIcons.reposicao,
                    title: 'Nenhuma solicitação encontrada',
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
                            _SolicitacaoRow(
                              solicitacao: resultado.items[i],
                              onAprovar: () => _aprovar(resultado.items[i]),
                              onRejeitar: () => _rejeitar(resultado.items[i]),
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

class _SolicitacaoRow extends StatelessWidget {
  const _SolicitacaoRow({required this.solicitacao, required this.onAprovar, required this.onRejeitar});

  final SolicitacaoReposicao solicitacao;
  final VoidCallback onAprovar;
  final VoidCallback onRejeitar;

  AppBadgeTone get _tone => switch (solicitacao.status) {
        SolicitacaoReposicaoStatus.pendente => AppBadgeTone.warning,
        SolicitacaoReposicaoStatus.aprovada => AppBadgeTone.success,
        SolicitacaoReposicaoStatus.rejeitada => AppBadgeTone.neutral,
      };

  String get _statusLabel => switch (solicitacao.status) {
        SolicitacaoReposicaoStatus.pendente => 'Pendente',
        SolicitacaoReposicaoStatus.aprovada => 'Aprovada',
        SolicitacaoReposicaoStatus.rejeitada => 'Rejeitada',
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(solicitacao.alunoNome, style: AppTypography.titleMedium.copyWith(color: colors.text)),
                    Text(
                      'Perdeu: ${dataCurtaFormat.format(solicitacao.aulaOrigemData)} · ${solicitacao.aulaOrigemTurmaNome}',
                      style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
                    ),
                    if (solicitacao.aulaDestinoId != null)
                      Text(
                        'Reposta em: ${dataCurtaFormat.format(solicitacao.aulaDestinoData!)} · ${solicitacao.aulaDestinoTurmaNome}',
                        style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
                      ),
                    if (solicitacao.motivoRejeicao != null)
                      Text(
                        'Motivo: ${solicitacao.motivoRejeicao}',
                        style: AppTypography.bodySmall.copyWith(color: colors.textFaint),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppBadge(_statusLabel, tone: _tone),
            ],
          ),
          if (solicitacao.status == SolicitacaoReposicaoStatus.pendente) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                AppButton(label: 'Aprovar', icon: AppIcons.circleCheck, onPressed: onAprovar),
                AppButton(
                  label: 'Rejeitar',
                  icon: AppIcons.circleX,
                  variant: AppButtonVariant.secondary,
                  onPressed: onRejeitar,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Aprovação — a recepção escolhe a aula de destino agora (docs/21,
/// decisão 3); a recontagem de capacidade acontece no backend, dentro da
/// transação, nunca aqui no frontend.
class _AprovarSolicitacaoDialog extends ConsumerStatefulWidget {
  const _AprovarSolicitacaoDialog({required this.solicitacao});

  final SolicitacaoReposicao solicitacao;

  @override
  ConsumerState<_AprovarSolicitacaoDialog> createState() => _AprovarSolicitacaoDialogState();
}

class _AprovarSolicitacaoDialogState extends ConsumerState<_AprovarSolicitacaoDialog> {
  Future<List<Aula>>? _aulasFuture;
  String? _aulaDestinoId;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _aulasFuture = ref
        .read(aulasApiProvider)
        .listCalendario(
          dataInicio: _iso(hoje),
          dataFim: _iso(hoje.add(const Duration(days: 90))),
          status: AulaStatus.agendada,
          pageSize: 100,
        )
        .then((resultado) => resultado.items);
  }

  String _iso(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';

  Future<void> _confirmar() async {
    setState(() => _erro = null);
    if (_aulaDestinoId == null) {
      setState(() => _erro = 'Selecione a aula de destino');
      return;
    }
    setState(() => _salvando = true);
    try {
      await ref.read(solicitacoesReposicaoApiProvider).aprovar(widget.solicitacao.id, _aulaDestinoId!);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: colors.border)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aprovar reposição', style: AppTypography.titleLarge.copyWith(color: colors.text)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${widget.solicitacao.alunoNome} — escolha a aula de destino (próximos 90 dias).',
                style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              FutureBuilder<List<Aula>>(
                future: _aulasFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingSkeleton(width: double.infinity, height: 48);
                  }
                  if (snapshot.hasError) {
                    return EmptyState(
                      icon: AppIcons.alert,
                      title: 'Não foi possível carregar as aulas.',
                    );
                  }
                  final aulas = snapshot.data!;
                  if (aulas.isEmpty) {
                    return const EmptyState(
                      icon: AppIcons.calendar,
                      title: 'Nenhuma aula agendada nos próximos 90 dias',
                    );
                  }
                  return AppSelect<String?>(
                    label: 'Aula de destino',
                    value: _aulaDestinoId,
                    options: [
                      for (final aula in aulas)
                        AppSelectOption(
                          value: aula.id,
                          label: '${dataCurtaFormat.format(aula.data)} · ${aula.turmaNome} · ${aula.horaInicio}',
                        ),
                    ],
                    onChanged: (v) => setState(() => _aulaDestinoId = v),
                  );
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
                  AppButton(label: 'Aprovar', loading: _salvando, onPressed: _confirmar),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RejeitarSolicitacaoDialog extends ConsumerStatefulWidget {
  const _RejeitarSolicitacaoDialog({required this.solicitacao});

  final SolicitacaoReposicao solicitacao;

  @override
  ConsumerState<_RejeitarSolicitacaoDialog> createState() => _RejeitarSolicitacaoDialogState();
}

class _RejeitarSolicitacaoDialogState extends ConsumerState<_RejeitarSolicitacaoDialog> {
  final _motivoController = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    setState(() => _erro = null);
    setState(() => _salvando = true);
    try {
      await ref.read(solicitacoesReposicaoApiProvider).rejeitar(
            widget.solicitacao.id,
            motivoRejeicao: _motivoController.text.trim().isEmpty ? null : _motivoController.text.trim(),
          );
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: colors.border)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rejeitar reposição', style: AppTypography.titleLarge.copyWith(color: colors.text)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Solicitação de ${widget.solicitacao.alunoNome}.',
                style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(label: 'Motivo (opcional)', controller: _motivoController, maxLines: 2),
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
                  AppButton(
                    label: 'Rejeitar',
                    variant: AppButtonVariant.danger,
                    loading: _salvando,
                    onPressed: _confirmar,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
