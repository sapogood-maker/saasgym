import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

/// Painel de detalhe do aluno — referência de composição para todo painel
/// de detalhe futuro (Professores, Turmas, ...): seções em `AppCard`,
/// pares rótulo/valor via `AppDetailRow` dentro de `AppFormRow` (mesmo
/// grid do formulário de edição da mesma entidade), seções ainda sem
/// funcionalidade como `EmptyState.comingSoon` com a tag da sprint
/// responsável — nunca dado inventado.
class AlunoDetailScreen extends ConsumerStatefulWidget {
  const AlunoDetailScreen({required this.alunoId, super.key});

  final String alunoId;

  @override
  ConsumerState<AlunoDetailScreen> createState() => _AlunoDetailScreenState();
}

class _AlunoDetailScreenState extends ConsumerState<AlunoDetailScreen> {
  Future<Aluno>? _future;
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
      _future = ref.read(alunosApiProvider).get(widget.alunoId);
    });
  }

  Future<void> _alternarStatus(Aluno aluno) async {
    setState(() => _processandoStatus = true);
    try {
      final novoStatus = aluno.status == UserStatus.ativo ? UserStatus.inativo : UserStatus.ativo;
      await ref.read(alunosApiProvider).updateStatus(aluno.id, novoStatus);
      _alterado = true;
      _carregar();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErroApi(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _processandoStatus = false);
      }
    }
  }

  Future<void> _excluir(Aluno aluno) async {
    final confirmou = await AppConfirmDialog.show(
      context,
      variant: AppConfirmDialogVariant.danger,
      title: 'Remover aluno',
      description: 'Remover ${aluno.nome}? O cadastro fica inativo e preservado (nada é apagado permanentemente).',
      confirmLabel: 'Remover',
    );
    if (confirmou != true || !mounted) {
      return;
    }

    setState(() => _removendo = true);
    try {
      await ref.read(alunosApiProvider).remove(aluno.id);
      if (mounted) {
        context.pop(true);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErroApi(e))));
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
      // igual ao AlunoFormScreen.
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: FutureBuilder<Aluno>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _AlunoPainelSkeleton();
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: AppIcons.alert,
                    title: 'Não foi possível carregar o aluno.',
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

  Widget _painel(BuildContext context, Aluno aluno) {
    final colors = context.colors;
    final ativo = aluno.status == UserStatus.ativo;

    // Bloco avatar+nome precisa de Expanded pro nome truncar em vez de
    // estourar — Row sem isso overflow assim que o espaço fica estreito
    // (mesmo padrão de bug já visto em AppButton/AppHeader/MetricCard).
    final info = Row(
      children: [
        AppAvatarPicker(imageUrl: aluno.fotoUrl, radius: 40, enabled: false),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                aluno.nome,
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
          ),
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
                  final resultado = await context.push<bool>('/alunos/${aluno.id}/editar');
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
          onPressed: _removendo ? null : () => _alternarStatus(aluno),
        ),
        AppButton(
          label: 'Remover',
          icon: AppIcons.trash,
          variant: AppButtonVariant.danger,
          loading: _removendo,
          onPressed: _processandoStatus ? null : () => _excluir(aluno),
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
          title: 'Dados pessoais',
          child: Column(
            children: [
              AppFormRow(children: [
                AppDetailRow(label: 'Nome', value: aluno.nome),
                AppDetailRow(label: 'CPF', value: aluno.cpf),
              ]),
              const SizedBox(height: AppSpacing.md),
              AppFormRow(children: [
                AppDetailRow(label: 'RG', value: aluno.rg),
                AppDetailRow(
                  label: 'Data de nascimento',
                  value: dataCurtaFormat.format(aluno.dataNascimento),
                ),
                AppDetailRow(label: 'Sexo', value: _sexoLabel(aluno.sexo)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Contato',
          child: AppFormRow(children: [
            AppDetailRow(label: 'Telefone', value: aluno.telefone),
            AppDetailRow(label: 'WhatsApp', value: aluno.whatsapp),
            AppDetailRow(label: 'E-mail', value: aluno.email),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Endereço',
          child: Column(
            children: [
              AppFormRow(children: [AppDetailRow(label: 'Endereço', value: aluno.endereco)]),
              const SizedBox(height: AppSpacing.md),
              AppFormRow(children: [
                AppDetailRow(label: 'Cidade', value: aluno.cidade),
                AppDetailRow(label: 'Estado', value: aluno.estado),
                AppDetailRow(label: 'CEP', value: aluno.cep),
              ]),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Observações',
          child: Text(
            (aluno.observacoes ?? '').trim().isNotEmpty ? aluno.observacoes! : '—',
            style: AppTypography.bodyMedium.copyWith(
              color: (aluno.observacoes ?? '').trim().isNotEmpty ? colors.text : colors.textFaint,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Matrículas',
          child: const EmptyState.comingSoon(
            icon: AppIcons.enrollment,
            title: 'Plano e matrícula do aluno',
            description: 'Vínculo com plano, data de início e vencimento.',
            sprintTag: 'MÓDULO 2 · MATRÍCULAS',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Financeiro',
          child: const EmptyState.comingSoon(
            icon: AppIcons.finance,
            title: 'Mensalidades e pagamentos',
            description: 'Histórico de cobranças, recebimentos e inadimplência.',
            sprintTag: 'MÓDULO 3 · FINANCEIRO',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Avaliações',
          child: const EmptyState.comingSoon(
            icon: AppIcons.assessment,
            title: 'Avaliação física',
            description: 'Peso, altura, IMC, dobras e medidas ao longo do tempo.',
            sprintTag: 'MÓDULO 5 · AVALIAÇÃO FÍSICA',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Frequência',
          child: const EmptyState.comingSoon(
            icon: AppIcons.attendance,
            title: 'Presença em aulas',
            description: 'Check-ins e frequência em aulas e treinos.',
            sprintTag: 'MÓDULO 4 · MS8',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Treinos',
          child: const EmptyState.comingSoon(
            icon: AppIcons.workout,
            title: 'Fichas de treino',
            description: 'Exercícios, séries, repetições e carga.',
            sprintTag: 'EM BREVE',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Arquivos',
          child: const EmptyState.comingSoon(
            icon: AppIcons.files,
            title: 'Documentos e anexos',
            description: 'Atestados, contratos e outros arquivos do aluno.',
            sprintTag: 'EM BREVE',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Histórico',
          child: const EmptyState.comingSoon(
            icon: AppIcons.history,
            title: 'Linha do tempo do aluno',
            description: 'Mudanças de plano, status e eventos importantes.',
            sprintTag: 'EM BREVE',
          ),
        ),
      ],
    );
  }
}

class _AlunoPainelSkeleton extends StatelessWidget {
  const _AlunoPainelSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const LoadingSkeleton(width: 80, height: 80, shape: AppSkeletonShape.circle),
            const SizedBox(width: AppSpacing.lg),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                LoadingSkeleton(width: 220, height: 28),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(width: 90, height: 20),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const AppCard(title: 'Dados pessoais', loading: true),
        const SizedBox(height: AppSpacing.lg),
        const AppCard(title: 'Contato', loading: true),
      ],
    );
  }
}

String _sexoLabel(Sexo sexo) {
  switch (sexo) {
    case Sexo.masculino:
      return 'Masculino';
    case Sexo.feminino:
      return 'Feminino';
    case Sexo.outro:
      return 'Outro';
  }
}

