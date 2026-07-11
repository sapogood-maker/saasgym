import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_icons.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';

/// Erro de formulário que não pertence a um campo específico — ex.: falha
/// de rede, ou uma regra que o backend rejeitou sem apontar um campo (CPF
/// duplicado, academia suspensa). Erro de campo continua sendo do campo
/// (`AppTextField`/`AppSelect`/`AppDateField`, chassi do MS1) — este banner
/// é especificamente para o que sobra: falha na operação de salvar como um
/// todo. Nunca `SnackBar` — mesmo princípio do erro de campo, só que em
/// escopo de formulário em vez de escopo de campo.
///
/// Exemplo:
/// ```dart
/// if (_erro != null) AppFormErrorBanner(_erro!)
/// ```
class AppFormErrorBanner extends StatelessWidget {
  final String message;

  const AppFormErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorWash,
        border: Border.all(color: colors.error.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AppIcons.alert, size: 16, color: colors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(message, style: AppTypography.bodySmall.copyWith(color: colors.error)),
            ),
          ],
        ),
      ),
    );
  }
}
