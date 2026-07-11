import 'package:flutter/material.dart';

/// Elevação do Design System — deliberadamente sutil. Sobre um fundo quase
/// preto, o contraste de um card vem mais da borda ([AppColorScheme.border])
/// que de sombra pesada; a sombra aqui é só um leve afastamento do plano de
/// fundo, não o `elevation` padrão do Material.
abstract final class AppShadows {
  /// Sombra padrão de [AppCard] e superfícies elevadas equivalentes.
  static const card = <BoxShadow>[
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 24,
      offset: Offset(0, 10),
      spreadRadius: -14,
    ),
  ];
}
