/// Faixas de largura do Design System. Desktop/notebook recebem a
/// experiência completa; tablet, uma boa experiência; celular, aceitável
/// mas sem esperar 100% das funcionalidades — degradação graciosa, não
/// redesenho mobile completo (decisão de escopo do produto).
abstract final class AppBreakpoints {
  /// Abaixo disso: layout de celular — sidebar colapsa.
  static const mobile = 600.0;

  /// Entre [mobile] e este valor: tablet. Acima: desktop.
  static const tablet = 1024.0;
}
