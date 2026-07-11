import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';

/// Tom semântico de [AppBadge]. [neutral] é rótulo sem conotação de estado
/// (contagem, tag, data); os demais representam o estado de um dado (ex.:
/// status de aluno) — nunca usar [primary] aqui, cor de marca não é estado.
enum AppBadgeTone { neutral, primary, success, warning, error, info }

/// Rótulo curto em formato de pílula — cobre tanto tag neutra (contagem,
/// data) quanto indicador de estado (ativo/pendente/inadimplente), variando
/// só a cor via [tone]. Um widget só, não um par "Badge" + "StatusChip"
/// quase idênticos.
///
/// Exemplo — estado de um aluno:
/// ```dart
/// AppBadge('Ativo', tone: AppBadgeTone.success)
/// AppBadge('Inadimplente', tone: AppBadgeTone.error)
/// ```
class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeTone tone;

  const AppBadge(this.label, {super.key, this.tone = AppBadgeTone.neutral});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (Color background, Color foreground) = switch (tone) {
      AppBadgeTone.neutral => (colors.cardRaised, colors.textMuted),
      AppBadgeTone.primary => (colors.primaryWash, colors.primaryStrong),
      AppBadgeTone.success => (colors.successWash, colors.success),
      AppBadgeTone.warning => (colors.warningWash, colors.warning),
      AppBadgeTone.error => (colors.errorWash, colors.error),
      AppBadgeTone.info => (colors.infoWash, colors.info),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: tone == AppBadgeTone.neutral ? Border.all(color: colors.border) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(color: foreground, letterSpacing: 0),
        ),
      ),
    );
  }
}
