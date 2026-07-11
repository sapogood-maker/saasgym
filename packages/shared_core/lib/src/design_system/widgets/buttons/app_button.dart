import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_colors.dart';
import '../../tokens/app_motion.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';

/// Variante visual de [AppButton]. Uma única classe de botão para todo o
/// produto — nunca criar um widget de botão específico de tela; se faltar
/// uma variante, ela entra aqui.
enum AppButtonVariant {
  /// Ação principal da tela — preenchimento sólido com a cor de marca.
  primary,

  /// Ação secundária — preenchimento neutro (superfície elevada).
  secondary,

  /// Ação de baixa ênfase, sem contorno nem preenchimento — ex.: "Cancelar"
  /// ao lado de um botão primary.
  ghost,

  /// Mesma ênfase de [ghost], mas com contorno visível — usar quando o
  /// botão precisa ser identificável mesmo sem estar perto de outro botão.
  outline,

  /// Ação destrutiva — ex.: excluir, revogar.
  danger,

  /// Ação de confirmação positiva fora do fluxo principal — ex.: aprovar,
  /// confirmar. Não usar como substituto de [primary]: [success] é para
  /// uma ação que representa um estado positivo, não a ação mais comum da tela.
  success,
}

/// Botão padrão do Design System — todas as telas do SaaSGym usam este
/// widget, nunca `ElevatedButton`/`TextButton` do Material puro. Uma única
/// classe cobre as 6 variantes de ênfase via [variant], em vez de um widget
/// por variante.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  /// Ícone opcional à esquerda do rótulo.
  final IconData? icon;

  /// Estado de carregamento — substitui o conteúdo por um spinner e ignora
  /// toques, mesmo que [onPressed] não seja nulo.
  final bool loading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
  });

  bool get _isDisabled => onPressed == null || loading;

  _ButtonPalette _paletteFor(AppColorScheme colors) {
    return switch (variant) {
      AppButtonVariant.primary => _ButtonPalette(
        background: colors.primary,
        backgroundHover: colors.primaryStrong,
        foreground: colors.primaryInk,
        border: null,
      ),
      AppButtonVariant.secondary => _ButtonPalette(
        background: colors.cardRaised,
        backgroundHover: colors.border,
        foreground: colors.text,
        border: BorderSide(color: colors.border),
      ),
      AppButtonVariant.ghost => _ButtonPalette(
        background: Colors.transparent,
        backgroundHover: colors.cardRaised,
        foreground: colors.textMuted,
        border: null,
      ),
      AppButtonVariant.outline => _ButtonPalette(
        background: Colors.transparent,
        backgroundHover: colors.cardRaised,
        foreground: colors.text,
        border: BorderSide(color: colors.border),
      ),
      AppButtonVariant.danger => _ButtonPalette(
        background: colors.error,
        backgroundHover: colors.error,
        foreground: colors.text,
        border: null,
      ),
      AppButtonVariant.success => _ButtonPalette(
        background: colors.success,
        backgroundHover: colors.success,
        foreground: colors.text,
        border: null,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(context.colors);

    return SizedBox(
      height: 40,
      child: TextButton(
        onPressed: _isDisabled ? null : onPressed,
        style: ButtonStyle(
          animationDuration: AppMotion.fast,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              side: palette.border ?? BorderSide.none,
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),
          textStyle: WidgetStatePropertyAll(
            AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          overlayColor: WidgetStatePropertyAll(
            palette.foreground.withValues(alpha: 0.08),
          ),
          // "disabled" aqui cobre dois casos com leitura visual diferente:
          // onPressed nulo de verdade (esmaece — não é possível interagir)
          // e loading (onPressed também vira nulo pra bloquear duplo clique,
          // mas o botão deve continuar com a cor cheia — está ativo, só
          // ocupado). Só o primeiro caso esmaece.
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled) && !loading) {
              return palette.background.withValues(alpha: 0.4);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.focused)) {
              return palette.backgroundHover;
            }
            return palette.background;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled) && !loading) {
              return palette.foreground.withValues(alpha: 0.5);
            }
            return palette.foreground;
          }),
        ),
        child: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(palette.foreground),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: palette.foreground),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  // Flexible + ellipsis: um rótulo longo (ex.: "Cadastrar
                  // primeiro aluno" dentro de um EmptyState estreito) trunca
                  // em vez de estourar o layout do Row.
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }
}

class _ButtonPalette {
  final Color background;
  final Color backgroundHover;
  final Color foreground;
  final BorderSide? border;

  const _ButtonPalette({
    required this.background,
    required this.backgroundHover,
    required this.foreground,
    required this.border,
  });
}
