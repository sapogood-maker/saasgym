import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

final _formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

/// Painel de detalhe do plano — Módulo 1 (MS5), mesmo padrão consolidado
/// por `AlunoDetailScreen`/`ProfessorDetailScreen`: seções em `AppCard`,
/// pares rótulo/valor via `AppDetailRow` dentro de `AppFormRow`, seções
/// ainda sem funcionalidade como `EmptyState.comingSoon` com a tag do
/// módulo responsável — nunca dado inventado.
///
/// Sem `AppAvatarPicker` no cabeçalho — Plano não é uma entidade "pessoa",
/// o círculo com ícone de perfil não se aplica ao domínio. Reuso é do
/// padrão de composição, não de usar todo componente que existe.
class PlanoDetailScreen extends ConsumerStatefulWidget {
  const PlanoDetailScreen({required this.planoId, super.key});

  final String planoId;

  @override
  ConsumerState<PlanoDetailScreen> createState() => _PlanoDetailScreenState();
}

class _PlanoDetailScreenState extends ConsumerState<PlanoDetailScreen> {
  Future<Plano>? _future;
  bool _alterado = false;
  bool _processandoStatus = false;
  bool _removendo = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _future = ref.read(planosApiProvider).get(widget.planoId);
    });
  }

  Future<void> _alternarStatus(Plano plano) async {
    setState(() => _processandoStatus = true);
    try {
      final novoStatus = plano.status == UserStatus.ativo ? UserStatus.inativo : UserStatus.ativo;
      await ref.read(planosApiProvider).updateStatus(plano.id, novoStatus);
      _alterado = true;
      _carregar();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_mensagemErro(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _processandoStatus = false);
      }
    }
  }

  Future<void> _excluir(Plano plano) async {
    final confirmou = await AppConfirmDialog.show(
      context,
      variant: AppConfirmDialogVariant.danger,
      title: 'Remover plano',
      description: 'Remover ${plano.nome}? O cadastro fica inativo e preservado (nada é apagado permanentemente).',
      confirmLabel: 'Remover',
    );
    if (confirmou != true || !mounted) {
      return;
    }

    setState(() => _removendo = true);
    try {
      await ref.read(planosApiProvider).remove(plano.id);
      if (mounted) {
        context.pop(true);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_mensagemErro(e))));
      }
      if (mounted) {
        setState(() => _removendo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.pop(_alterado);
        }
      },
      // Rota fora do ShellRoute (tela cheia) — precisa do próprio Scaffold,
      // igual ao PlanoFormScreen.
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: FutureBuilder<Plano>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _PlanoPainelSkeleton();
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: AppIcons.alert,
                    title: 'Não foi possível carregar o plano.',
                    actionLabel: 'Tentar novamente',
                    onAction: _carregar,
                  );
                }
                return _painel(context, snapshot.data!);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _painel(BuildContext context, Plano plano) {
    final colors = context.colors;
    final ativo = plano.status == UserStatus.ativo;

    // `info` fica sem Expanded aqui — só é envolvido no ponto de uso do
    // Row desktop (constraints largas). No Column mobile (dentro de um
    // SingleChildScrollView, altura irrestrita) o Expanded quebraria o
    // layout — mesmo padrão de bug já visto em AppButton/AppHeader/
    // MetricCard/AppPagination, agora na direção inversa.
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          plano.nome,
          style: AppTypography.displayLarge.copyWith(color: colors.text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppBadge(
          ativo ? 'Ativo' : 'Inativo',
          tone: ativo ? AppBadgeTone.success : AppBadgeTone.neutral,
        ),
      ],
    );

    final acoes = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppButton(
          label: 'Editar',
          icon: AppIcons.edit,
          onPressed: (_processandoStatus || _removendo)
              ? null
              : () async {
                  final resultado = await context.push<bool>('/planos/${plano.id}/editar');
                  if (resultado == true) {
                    _alterado = true;
                    _carregar();
                  }
                },
        ),
        AppButton(
          label: ativo ? 'Inativar' : 'Reativar',
          icon: ativo ? AppIcons.block : AppIcons.circleCheck,
          variant: AppButtonVariant.secondary,
          loading: _processandoStatus,
          onPressed: _removendo ? null : () => _alternarStatus(plano),
        ),
        AppButton(
          label: 'Remover',
          icon: AppIcons.trash,
          variant: AppButtonVariant.danger,
          loading: _removendo,
          onPressed: _processandoStatus ? null : () => _excluir(plano),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (context.isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [info, const SizedBox(height: AppSpacing.lg), acoes],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: info), const SizedBox(width: AppSpacing.lg), acoes],
          ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          title: 'Dados do plano',
          child: Column(
            children: [
              AppFormRow(children: [
                AppDetailRow(label: 'Nome', value: plano.nome),
              ]),
              const SizedBox(height: AppSpacing.md),
              AppFormRow(children: [
                AppDetailRow(label: 'Periodicidade', value: _periodicidadeLabel(plano.periodicidade)),
                AppDetailRow(label: 'Valor', value: _formatoMoeda.format(plano.valor)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Detalhes',
          child: AppFormRow(children: [
            AppDetailRow(
              label: 'Quantidade de aulas',
              value: plano.quantidadeAulas != null ? '${plano.quantidadeAulas}' : 'Ilimitado',
            ),
            AppDetailRow(label: 'Ordem de exibição', value: plano.ordem?.toString()),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Observações',
          child: Text(
            (plano.descricao ?? '').trim().isNotEmpty ? plano.descricao! : '—',
            style: AppTypography.bodyMedium.copyWith(
              color: (plano.descricao ?? '').trim().isNotEmpty ? colors.text : colors.textFaint,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Alunos matriculados',
          child: const EmptyState.comingSoon(
            icon: AppIcons.enrollment,
            title: 'Alunos com este plano',
            description: 'Quem está matriculado, desde quando e até quando.',
            sprintTag: 'MÓDULO 2 · MATRÍCULAS',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Financeiro',
          child: const EmptyState.comingSoon(
            icon: AppIcons.finance,
            title: 'Receita gerada por este plano',
            description: 'Mensalidades geradas, recebidas e em aberto.',
            sprintTag: 'MÓDULO 3 · FINANCEIRO',
          ),
        ),
      ],
    );
  }
}

class _PlanoPainelSkeleton extends StatelessWidget {
  const _PlanoPainelSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LoadingSkeleton(width: 220, height: 28),
        SizedBox(height: AppSpacing.sm),
        LoadingSkeleton(width: 90, height: 20),
        SizedBox(height: AppSpacing.xl),
        AppCard(title: 'Dados do plano', loading: true),
        SizedBox(height: AppSpacing.lg),
        AppCard(title: 'Detalhes', loading: true),
      ],
    );
  }
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

String _mensagemErro(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['message'] != null) {
    final message = data['message'];
    return message is List ? message.join(', ') : message.toString();
  }
  return 'Não foi possível concluir a operação.';
}
