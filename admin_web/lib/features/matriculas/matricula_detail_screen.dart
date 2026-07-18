import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

import '../../routing/back_navigation.dart';

final _formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

/// Painel de detalhe da matrícula — Módulo 2 (MS5), mesmo padrão
/// consolidado por `AlunoDetailScreen`/`ProfessorDetailScreen`/
/// `PlanoDetailScreen`: seções em `AppCard`, pares rótulo/valor via
/// `AppDetailRow` dentro de `AppFormRow`.
///
/// Concentra as transições de ciclo de vida (trancar/reativar/cancelar/
/// renovar) que o Formulário (MS4) deliberadamente não tem — ver
/// docs/16-modulo-2-matriculas-analise.md, seção "Matriz de estados e
/// transições (MS5)", pra qual ação é permitida em qual `MatriculaStatus`
/// e por quê. Botões renderizam só as ações que o backend aceita pro
/// status atual (nunca um botão que sempre daria 400).
///
/// `Cancelar` abre um diálogo próprio (`_CancelarMatriculaDialog`), não
/// `AppConfirmDialog` — motivo é um enum categorizado obrigatório
/// (`MotivoCancelamento`) + detalhe condicional, não cabe num
/// título/descrição estáticos. Reaproveita os mesmos átomos do Design
/// System (`AppSelect`/`AppTextField`/`AppButton`) com o mesmo chassi
/// visual do `AppConfirmDialog` (Dialog + card + `AppRadius.lg`) — não é
/// um componente novo do Design System, é uma composição específica do
/// domínio de Matrícula, do mesmo jeito que a tela toda já é.
class MatriculaDetailScreen extends ConsumerStatefulWidget {
  const MatriculaDetailScreen({required this.matriculaId, super.key});

  final String matriculaId;

  @override
  ConsumerState<MatriculaDetailScreen> createState() => _MatriculaDetailScreenState();
}

class _MatriculaDetailScreenState extends ConsumerState<MatriculaDetailScreen> {
  Future<Matricula>? _future;
  bool _alterado = false;
  bool _processando = false;
  bool _removendo = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _future = ref.read(matriculasApiProvider).get(widget.matriculaId);
    });
  }

  void _voltar([bool? alterado]) {
    context.backToList('/matriculas', result: alterado ?? _alterado);
  }

  Future<void> _trancar() async {
    final confirmou = await AppConfirmDialog.show(
      context,
      variant: AppConfirmDialogVariant.warning,
      title: 'Trancar matrícula',
      description: 'A matrícula fica pausada — o aluno não é cobrado enquanto estiver trancada. Reativar depois estende a vigência pelos dias congelados.',
      confirmLabel: 'Trancar',
    );
    if (confirmou != true || !mounted) return;

    setState(() => _processando = true);
    try {
      await ref.read(matriculasApiProvider).trancar(widget.matriculaId);
      _alterado = true;
      _carregar();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErroApi(e))));
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _reativar() async {
    final confirmou = await AppConfirmDialog.show(
      context,
      title: 'Reativar matrícula',
      description: 'A cobrança volta a valer. A vigência é estendida pelos dias em que a matrícula ficou congelada.',
      confirmLabel: 'Reativar',
    );
    if (confirmou != true || !mounted) return;

    setState(() => _processando = true);
    try {
      await ref.read(matriculasApiProvider).reativar(widget.matriculaId);
      _alterado = true;
      _carregar();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErroApi(e))));
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _cancelar() async {
    final resultado = await showAppDialog<_CancelarPayload>(
      context,
      maxWidth: 420,
      builder: (_) => const _CancelarMatriculaDialog(),
    );
    if (resultado == null || !mounted) return;

    setState(() => _processando = true);
    try {
      await ref.read(matriculasApiProvider).cancelar(
        widget.matriculaId,
        motivoCancelamento: resultado.motivo,
        motivoCancelamentoDetalhe: resultado.detalhe,
      );
      _alterado = true;
      _carregar();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErroApi(e))));
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _renovar() async {
    final confirmou = await AppConfirmDialog.show(
      context,
      title: 'Renovar matrícula',
      description: 'Encerra esta matrícula e cria a próxima, no mesmo plano, começando no dia seguinte ao fim desta vigência. Valor e dia de vencimento podem ser ajustados depois, no formulário da nova matrícula.',
      confirmLabel: 'Renovar',
    );
    if (confirmou != true || !mounted) return;

    setState(() => _processando = true);
    try {
      final nova = await ref.read(matriculasApiProvider).renovar(widget.matriculaId);
      _alterado = true;
      // Recarrega ESTA tela (agora ENCERRADA, todas as ações somem) em vez
      // de navegar sozinho pra nova — `context.pushReplacement` nesta
      // versão do go_router não devolve o `Future<bool>` que a lista
      // espera pra saber se precisa recarregar, então o usuário decide
      // via ação do SnackBar, não uma navegação automática.
      _carregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Matrícula renovada com sucesso.'),
            action: SnackBarAction(
              label: 'Ver nova',
              onPressed: () => context.push('/matriculas/${nova.id}'),
            ),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErroApi(e))));
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _remover(Matricula matricula) async {
    final confirmou = await AppConfirmDialog.show(
      context,
      variant: AppConfirmDialogVariant.danger,
      title: 'Remover matrícula',
      description:
          'Reservado a corrigir um cadastro feito por engano — some da lista, mas nada é apagado permanentemente. Para um encerramento de verdade (com motivo registrado), use Cancelar em vez disto.',
      confirmLabel: 'Remover',
    );
    if (confirmou != true || !mounted) return;

    setState(() => _removendo = true);
    try {
      await ref.read(matriculasApiProvider).remove(matricula.id);
      if (mounted) {
        _voltar(true);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErroApi(e))));
      }
      if (mounted) setState(() => _removendo = false);
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
      // igual ao MatriculaFormScreen.
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: FutureBuilder<Matricula>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _MatriculaPainelSkeleton(onBack: _voltar);
                }
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppBackLink(label: 'Matrículas', onTap: _voltar),
                      const SizedBox(height: AppSpacing.lg),
                      EmptyState(
                        icon: AppIcons.alert,
                        title: 'Não foi possível carregar a matrícula.',
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

  Widget _painel(BuildContext context, Matricula matricula) {
    final status = matricula.status;
    final bloqueado = _processando || _removendo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDetailHeader(
          listLabel: 'Matrículas',
          onBack: _voltar,
          leading: AppAvatarPicker(imageUrl: matricula.alunoFotoUrl, radius: 40, enabled: false),
          title: matricula.alunoNome,
          subtitle: matricula.planoNome,
          trailing: AppBadge(_statusLabel(status), tone: _statusTone(status)),
          // Matriz de estados e transições — ver docs/16, seção "Matriz de
          // estados e transições (MS5)". Cada ação só aparece quando o
          // backend de fato aceita a transição pro status atual.
          actions: [
            AppButton(
              label: 'Editar',
              icon: AppIcons.edit,
              onPressed: (status == MatriculaStatus.cancelada || status == MatriculaStatus.encerrada || bloqueado)
                  ? null
                  : () async {
                      final resultado = await context.push<bool>('/matriculas/${matricula.id}/editar');
                      if (resultado == true) {
                        _alterado = true;
                        _carregar();
                      }
                    },
            ),
            if (status == MatriculaStatus.ativa)
              AppButton(
                label: 'Trancar',
                icon: AppIcons.block,
                variant: AppButtonVariant.secondary,
                loading: _processando,
                onPressed: _removendo ? null : _trancar,
              ),
            if (status == MatriculaStatus.trancada)
              AppButton(
                label: 'Reativar',
                icon: AppIcons.circleCheck,
                variant: AppButtonVariant.secondary,
                loading: _processando,
                onPressed: _removendo ? null : _reativar,
              ),
            if (status == MatriculaStatus.ativa)
              AppButton(
                label: 'Renovar',
                icon: AppIcons.history,
                variant: AppButtonVariant.secondary,
                loading: _processando,
                onPressed: _removendo ? null : _renovar,
              ),
            if (status == MatriculaStatus.ativa || status == MatriculaStatus.trancada)
              AppButton(
                label: 'Cancelar',
                icon: AppIcons.circleX,
                variant: AppButtonVariant.secondary,
                loading: _processando,
                onPressed: _removendo ? null : _cancelar,
              ),
            AppButton(
              label: 'Remover',
              icon: AppIcons.trash,
              variant: AppButtonVariant.danger,
              loading: _removendo,
              onPressed: _processando ? null : () => _remover(matricula),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          title: 'Dados da matrícula',
          child: Column(
            children: [
              AppFormRow(children: [
                AppDetailRow(label: 'Aluno', value: matricula.alunoNome),
                AppDetailRow(label: 'Plano', value: matricula.planoNome),
              ]),
              const SizedBox(height: AppSpacing.md),
              AppFormRow(children: [
                AppDetailRow(label: 'Valor mensal', value: _formatoMoeda.format(matricula.valor)),
                AppDetailRow(label: 'Dia de vencimento', value: matricula.diaVencimento.toString()),
              ]),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Vigência',
          child: Column(
            children: [
              AppFormRow(children: [
                AppDetailRow(label: 'Data de início', value: dataCurtaFormat.format(matricula.dataInicio)),
                AppDetailRow(label: 'Fim previsto', value: dataCurtaFormat.format(matricula.dataFimPrevista)),
                AppDetailRow(label: 'Fim vigente', value: dataCurtaFormat.format(matricula.dataFim)),
              ]),
              if (status == MatriculaStatus.trancada) ...[
                const SizedBox(height: AppSpacing.md),
                AppFormRow(children: [
                  AppDetailRow(
                    label: 'Trancada em',
                    value: matricula.trancadoEm != null ? dataCurtaFormat.format(matricula.trancadoEm!) : null,
                  ),
                  AppDetailRow(label: 'Motivo do trancamento', value: matricula.trancamentoMotivo),
                ]),
              ],
              if (matricula.matriculaAnteriorId != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppFormRow(children: [
                  const AppDetailRow(label: 'Origem', value: 'Renovação de outra matrícula'),
                ]),
              ],
            ],
          ),
        ),
        if (status == MatriculaStatus.cancelada) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            title: 'Cancelamento',
            child: AppFormRow(children: [
              AppDetailRow(
                label: 'Motivo',
                value: matricula.motivoCancelamento != null
                    ? _motivoCancelamentoLabel(matricula.motivoCancelamento!)
                    : null,
              ),
              AppDetailRow(label: 'Detalhe', value: matricula.motivoCancelamentoDetalhe),
            ]),
          ),
        ],
      ],
    );
  }
}

class _MatriculaPainelSkeleton extends StatelessWidget {
  const _MatriculaPainelSkeleton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppBackLink(label: 'Matrículas', onTap: onBack),
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
                LoadingSkeleton(width: 140, height: 18),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(width: 90, height: 20),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const AppCard(title: 'Dados da matrícula', loading: true),
        const SizedBox(height: AppSpacing.lg),
        const AppCard(title: 'Vigência', loading: true),
      ],
    );
  }
}

class _CancelarPayload {
  const _CancelarPayload({required this.motivo, this.detalhe});

  final MotivoCancelamento motivo;
  final String? detalhe;
}

/// Diálogo de cancelamento — mesmo chassi visual do `AppConfirmDialog`
/// (Dialog + `colors.card` + `AppRadius.lg`), mas com campos: motivo é um
/// enum categorizado obrigatório, não cabe num `description` estático.
/// Não é um componente novo do Design System — é específico do domínio de
/// Matrícula (só esta tela usa), composto com `AppSelect`/`AppTextField`/
/// `AppButton`/`AppFormErrorBanner` já existentes.
class _CancelarMatriculaDialog extends StatefulWidget {
  const _CancelarMatriculaDialog();

  @override
  State<_CancelarMatriculaDialog> createState() => _CancelarMatriculaDialogState();
}

class _CancelarMatriculaDialogState extends State<_CancelarMatriculaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _detalheController = TextEditingController();
  MotivoCancelamento? _motivo;
  String? _erro;

  @override
  void dispose() {
    _detalheController.dispose();
    super.dispose();
  }

  void _confirmar() {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    if (_motivo == null) {
      setState(() => _erro = 'Selecione o motivo do cancelamento');
      return;
    }
    Navigator.of(context).pop(
      _CancelarPayload(
        motivo: _motivo!,
        detalhe: _detalheController.text.trim().isEmpty ? null : _detalheController.text.trim(),
      ),
    );
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
          Text('Cancelar matrícula', style: AppTypography.titleLarge.copyWith(color: colors.text)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Encerramento definitivo — preserva o histórico pra métricas de churn.',
            style: AppTypography.bodyMedium.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSelect<MotivoCancelamento?>(
            label: 'Motivo',
            value: _motivo,
            options: const [
              AppSelectOption(value: MotivoCancelamento.alunoSolicitou, label: 'Aluno solicitou'),
              AppSelectOption(value: MotivoCancelamento.inadimplencia, label: 'Inadimplência'),
              AppSelectOption(value: MotivoCancelamento.academiaCancelou, label: 'Academia cancelou'),
              AppSelectOption(value: MotivoCancelamento.outro, label: 'Outro'),
            ],
            onChanged: (v) => setState(() => _motivo = v),
          ),
          if (_motivo == MotivoCancelamento.outro) ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Detalhe',
              hintText: 'Descreva o motivo',
              controller: _detalheController,
              maxLines: 2,
              validator: (v) => (v == null || v.trim().length < 3) ? 'Detalhe o motivo' : null,
            ),
          ],
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
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(label: 'Confirmar cancelamento', variant: AppButtonVariant.danger, onPressed: _confirmar),
            ],
          ),
        ],
      ),
    );
  }
}

String _motivoCancelamentoLabel(MotivoCancelamento motivo) => switch (motivo) {
  MotivoCancelamento.alunoSolicitou => 'Aluno solicitou',
  MotivoCancelamento.inadimplencia => 'Inadimplência',
  MotivoCancelamento.academiaCancelou => 'Academia cancelou',
  // Nunca escolhido manualmente (não aparece nas opções do diálogo acima)
  // — só o cascade automático de arquivamento/remoção de aluno usa esse
  // motivo (docs/32), mas a matrícula já cancelada continua exibindo o
  // motivo real aqui, em vez de quebrar o switch exaustivo.
  MotivoCancelamento.alunoArquivado => 'Aluno arquivado',
  MotivoCancelamento.outro => 'Outro',
};

