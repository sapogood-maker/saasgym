import 'package:flutter/material.dart';

/// Tema Material 3 compartilhado entre admin_web e student_web.
///
/// Mantém os dois frontends visualmente consistentes sem duplicar definição
/// de cores/tipografia em cada app.
abstract final class AppTheme {
  static const _seedColor = Color(0xFF2E6B4F);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
    );
  }
}
