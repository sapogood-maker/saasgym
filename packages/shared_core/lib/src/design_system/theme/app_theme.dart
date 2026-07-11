import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';

/// Monta o [ThemeData] do SaaSGym a partir dos tokens do Design System.
/// Único tema hoje é [darkPremium] — não existe `themeMode`/`darkTheme`
/// porque dark é o único tema do produto (decisão de produto, não uma
/// implementação parcial).
abstract final class AppTheme {
  static ThemeData darkPremium() {
    final colors = AppColorScheme.darkPremium();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.background,
      fontFamily: AppTypography.displayLarge.fontFamily,
      extensions: [colors],
      // ColorScheme do Material preenchido a partir dos mesmos tokens, só
      // para os poucos widgets nativos do Flutter que exigem um
      // ColorScheme (Scrollbar, DatePicker…) — nunca usar como fonte de
      // verdade em tela própria, preferir sempre `context.colors`.
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        brightness: Brightness.dark,
        surface: colors.surface,
        error: colors.error,
      ),
    );
  }
}
