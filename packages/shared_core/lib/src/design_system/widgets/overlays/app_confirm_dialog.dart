import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_icons.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';
import '../buttons/app_button.dart';
import 'app_dialog.dart';

/// Tom do [AppConfirmDialog] — controla ícone e cor de destaque. Só
/// [confirm] e [danger] têm uso real hoje (confirmar ação / excluir); os
/// outros três (`warning`/`success`/`error`) já existem na API pra não
/// exigir mudança de assinatura quando um fluxo de aviso/sucesso/erro
/// aparecer — sem inventar uso pra eles agora.
enum AppConfirmDialogVariant { confirm, danger, warning, success, error }

/// Diálogo de confirmação do Design System — único diálogo de decisão do
/// produto (nunca `AlertDialog` cru numa tela de feature). Não sabe nada
/// sobre domínio: título, descrição e rótulos dos botões vêm de quem
/// chama; o componente só decide o ícone/cor a partir de [variant].
///
/// Exemplo:
/// ```dart
/// final confirmou = await AppConfirmDialog.show(
///   context,
///   variant: AppConfirmDialogVariant.danger,
///   title: 'Remover aluno',
///   description: 'Remover Mariana Ferreira? O cadastro fica inativo e preservado.',
///   confirmLabel: 'Remover',
/// );
/// if (confirmou == true) { ... }
/// ```
class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String description;
  final String confirmLabel;
  final String cancelLabel;
  final AppConfirmDialogVariant variant;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.description,
    this.confirmLabel = 'Confirmar',
    this.cancelLabel = 'Cancelar',
    this.variant = AppConfirmDialogVariant.confirm,
  });

  /// Abre o diálogo e resolve `true` (confirmou), `false` (cancelou) ou
  /// `null` (fechou sem escolher — ex.: tocou fora ou apertou Esc).
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String description,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    AppConfirmDialogVariant variant = AppConfirmDialogVariant.confirm,
  }) {
    return showAppDialog<bool>(
      context,
      maxWidth: 380,
      builder: (_) => AppConfirmDialog(
        title: title,
        description: description,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        variant: variant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, tone, confirmVariant) = switch (variant) {
      AppConfirmDialogVariant.confirm => (AppIcons.circleHelp, colors.info, AppButtonVariant.primary),
      AppConfirmDialogVariant.danger => (AppIcons.trash, colors.error, AppButtonVariant.danger),
      AppConfirmDialogVariant.warning => (AppIcons.alert, colors.warning, AppButtonVariant.primary),
      AppConfirmDialogVariant.success => (AppIcons.circleCheck, colors.success, AppButtonVariant.success),
      AppConfirmDialogVariant.error => (AppIcons.circleX, colors.error, AppButtonVariant.danger),
    };
    final Color toneWash = switch (variant) {
      AppConfirmDialogVariant.confirm => colors.infoWash,
      AppConfirmDialogVariant.danger => colors.errorWash,
      AppConfirmDialogVariant.warning => colors.warningWash,
      AppConfirmDialogVariant.success => colors.successWash,
      AppConfirmDialogVariant.error => colors.errorWash,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: toneWash,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Icon(icon, size: 20, color: tone),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: AppTypography.titleLarge.copyWith(color: colors.text)),
        const SizedBox(height: AppSpacing.xs),
        Text(description, style: AppTypography.bodyMedium.copyWith(color: colors.textMuted)),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              label: cancelLabel,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              label: confirmLabel,
              variant: confirmVariant,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ],
    );
  }
}
