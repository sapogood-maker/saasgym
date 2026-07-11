import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_icons.dart';
import '../../tokens/app_motion.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';

/// Casca visual compartilhada por [AppTextField]/[AppSelect]/[AppDateField]
/// — label, borda, ícone de prefixo e a linha de erro/ajuda. **Não é um
/// componente público do Design System**: é implementação interna
/// (prefixo `_`, arquivo prefixado `_`) que garante que os três campos
/// tenham exatamente o mesmo visual de erro sem triplicar código. Se
/// algum widget de tela precisar dessa casca, é sinal de que falta um
/// componente de campo novo — nunca importar este arquivo fora de
/// `widgets/inputs/`.
///
/// Padrão de erro do projeto (único em todo o sistema): borda vermelha +
/// mensagem abaixo do campo + ícone discreto + transição suave. Nunca via
/// `SnackBar` — erro pertence ao campo.
class AppFieldChrome extends StatelessWidget {
  final String label;
  final String? errorText;
  final String? helperText;
  final IconData? prefixIcon;
  final bool focused;
  final bool enabled;
  final Widget child;

  const AppFieldChrome({
    super.key,
    required this.label,
    required this.child,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.focused = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasError = errorText != null && errorText!.isNotEmpty;

    final Color borderColor = !enabled
        ? colors.borderSoft
        : hasError
        ? colors.error
        : focused
        ? colors.primary
        : colors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: enabled ? colors.textMuted : colors.textFaint,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curveStandard,
          decoration: BoxDecoration(
            color: enabled ? colors.surface : colors.card,
            border: Border.all(color: borderColor, width: hasError || focused ? 1.5 : 1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                Icon(prefixIcon, size: 16, color: colors.textFaint),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(child: child),
            ],
          ),
        ),
        AnimatedSize(
          duration: AppMotion.fast,
          curve: AppMotion.curveStandard,
          alignment: Alignment.topLeft,
          child: (hasError || helperText != null)
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasError) ...[
                        Icon(AppIcons.alert, size: 12, color: colors.error),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Flexible(
                        child: Text(
                          hasError ? errorText! : helperText!,
                          style: AppTypography.bodySmall.copyWith(
                            color: hasError ? colors.error : colors.textFaint,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
