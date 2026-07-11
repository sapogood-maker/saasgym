import 'package:flutter/widgets.dart';

/// Duração e curva de animação do Design System. "Discreto" é a palavra de
/// ordem — nada chamativo: fade, slide e hover curtos, sempre com a mesma
/// curva, para que toda transição do produto se sinta parte do mesmo
/// sistema em vez de cada tela inventar seu próprio tempo/aceleração.
abstract final class AppMotion {
  /// Hover, ripple, foco — resposta quase instantânea.
  static const fast = Duration(milliseconds: 120);

  /// Transição de estado padrão (fade, troca de conteúdo, expandir/colapsar).
  static const base = Duration(milliseconds: 180);

  /// Entrada de painel maior, skeleton → conteúdo carregado.
  static const slow = Duration(milliseconds: 280);

  /// Curva padrão de toda animação do Design System — mais "assentada" no
  /// fim do movimento que o `Curves.easeInOut` genérico do Material.
  static const curveStandard = Cubic(0.2, 0, 0, 1);

  /// Resolve a duração real a usar, respeitando a preferência de
  /// acessibilidade "reduzir movimento" da plataforma — todo widget do
  /// Design System que anima deve passar por aqui em vez de usar a
  /// constante ([fast]/[base]/[slow]) diretamente.
  static Duration durationFor(BuildContext context, Duration duration) {
    return MediaQuery.of(context).disableAnimations ? Duration.zero : duration;
  }
}
