/// Escala de espaçamento do Design System — toda `SizedBox`/`EdgeInsets`
/// de tela nova usa um destes valores, nunca um número solto. Escala de
/// 4pt, igual à base usada por Stripe/Linear (substitui a mistura ad hoc
/// de 8/12/16/24/32 encontrada nas telas anteriores ao Design System).
abstract final class AppSpacing {
  /// 4 — respiro mínimo (ex.: entre ícone e texto colado).
  static const xs = 4.0;

  /// 8 — espaçamento entre elementos muito próximos (ex.: rótulo e valor).
  static const sm = 8.0;

  /// 12 — espaçamento padrão dentro de um componente (ex.: padding interno de um chip).
  static const md = 12.0;

  /// 16 — espaçamento padrão entre elementos de uma lista ou coluna.
  static const lg = 16.0;

  /// 24 — respiro padrão de padding de página/card.
  static const xl = 24.0;

  /// 32 — separação entre seções de uma tela.
  static const xxl = 32.0;

  /// 48 — respiro grande (ex.: topo de um estado vazio).
  static const xxxl = 48.0;
}
