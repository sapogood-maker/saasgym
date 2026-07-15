import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

import '../../routing/back_navigation.dart';

/// Painel de detalhe do professor — Sprint 3, reescrita 1:1 do padrão
/// consolidado por `AlunoDetailScreen` (Sprint 2, MS5). As seções futuras
/// não são as mesmas de Aluno (Turmas/Financeiro fazem sentido para um
/// professor; Avaliações/Frequência/Treinos não) — reuso é do padrão de
/// composição (AppCard + EmptyState.comingSoon), não da lista de seções.
class ProfessorDetailScreen extends ConsumerStatefulWidget {
  const ProfessorDetailScreen({required this.professorId, super.key});

  final String professorId;

  @override
  ConsumerState<ProfessorDetailScreen> createState() => _ProfessorDetailScreenState();
}

class _ProfessorDetailScreenState extends ConsumerState<ProfessorDetailScreen> {
  Future<Professor>? _future;
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
      _future = ref.read(professoresApiProvider).get(widget.professorId);
    });
  }

  void _voltar([bool? alterado]) {
    context.backToList('/professores', result: alterado ?? _alterado);
  }

  Future<void> _alternarStatus(Professor professor) async {
    setState(() => _processandoStatus = true);
    try {
      final novoStatus = professor.status == UserStatus.ativo ? UserStatus.inativo : UserStatus.ativo;
      await ref.read(professoresApiProvider).updateStatus(professor.id, novoStatus);
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

  Future<void> _excluir(Professor professor) async {
    final confirmou = await AppConfirmDialog.show(
      context,
      variant: AppConfirmDialogVariant.danger,
      title: 'Remover professor',
      description: 'Remover ${professor.nome}? O cadastro fica inativo e preservado (nada é apagado permanentemente).',
      confirmLabel: 'Remover',
    );
    if (confirmou != true || !mounted) {
      return;
    }

    setState(() => _removendo = true);
    try {
      await ref.read(professoresApiProvider).remove(professor.id);
      if (mounted) {
        _voltar(true);
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
          _voltar();
        }
      },
      // Rota fora do ShellRoute (tela cheia) — precisa do próprio Scaffold,
      // igual ao ProfessorFormScreen/AlunoDetailScreen.
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: FutureBuilder<Professor>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _ProfessorPainelSkeleton(onBack: _voltar);
                }
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppBackLink(label: 'Professores', onTap: _voltar),
                      const SizedBox(height: AppSpacing.lg),
                      EmptyState(
                        icon: AppIcons.alert,
                        title: 'Não foi possível carregar o professor.',
                        actionLabel: 'Tentar novamente',
                        onAction: _carregar,
                      ),
                    ],
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

  Widget _painel(BuildContext context, Professor professor) {
    final colors = context.colors;
    final ativo = professor.status == UserStatus.ativo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDetailHeader(
          listLabel: 'Professores',
          onBack: _voltar,
          leading: AppAvatarPicker(imageUrl: professor.fotoUrl, radius: 40, enabled: false),
          title: professor.nome,
          trailing: AppBadge(
            ativo ? 'Ativo' : 'Inativo',
            tone: ativo ? AppBadgeTone.success : AppBadgeTone.neutral,
          ),
          actions: [
            AppButton(
              label: 'Editar',
              icon: AppIcons.edit,
              onPressed: (_processandoStatus || _removendo)
                  ? null
                  : () async {
                      final resultado = await context.push<bool>('/professores/${professor.id}/editar');
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
              onPressed: _removendo ? null : () => _alternarStatus(professor),
            ),
            AppButton(
              label: 'Remover',
              icon: AppIcons.trash,
              variant: AppButtonVariant.danger,
              loading: _removendo,
              onPressed: _processandoStatus ? null : () => _excluir(professor),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          title: 'Dados pessoais',
          child: AppFormRow(children: [
            AppDetailRow(label: 'Nome', value: professor.nome),
            AppDetailRow(label: 'CPF', value: professor.cpf),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Contato',
          child: AppFormRow(children: [
            AppDetailRow(label: 'Telefone', value: professor.telefone),
            AppDetailRow(label: 'E-mail', value: professor.email),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Dados profissionais',
          child: AppFormRow(children: [
            AppDetailRow(label: 'Especialidade', value: professor.especialidade),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Observações',
          child: Text(
            (professor.observacoes ?? '').trim().isNotEmpty ? professor.observacoes! : '—',
            style: AppTypography.bodyMedium.copyWith(
              color: (professor.observacoes ?? '').trim().isNotEmpty ? colors.text : colors.textFaint,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Turmas',
          child: const EmptyState.comingSoon(
            icon: AppIcons.calendar,
            title: 'Aulas e turmas do professor',
            description: 'Turmas, horários e alunos vinculados.',
            sprintTag: 'MÓDULO 4 · MS6',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Financeiro',
          child: const EmptyState.comingSoon(
            icon: AppIcons.finance,
            title: 'Pagamentos e comissões',
            description: 'Histórico de pagamentos ao professor.',
            sprintTag: 'MÓDULO 3 · FINANCEIRO',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Arquivos',
          child: const EmptyState.comingSoon(
            icon: AppIcons.files,
            title: 'Documentos e anexos',
            description: 'Certificados, contratos e outros arquivos do professor.',
            sprintTag: 'EM BREVE',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Histórico',
          child: const EmptyState.comingSoon(
            icon: AppIcons.history,
            title: 'Linha do tempo do professor',
            description: 'Mudanças de status e eventos importantes.',
            sprintTag: 'EM BREVE',
          ),
        ),
      ],
    );
  }
}

class _ProfessorPainelSkeleton extends StatelessWidget {
  const _ProfessorPainelSkeleton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppBackLink(label: 'Professores', onTap: onBack),
        const SizedBox(height: AppSpacing.lg),
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

