import 'package:flutter/widgets.dart';

/// Escala tipográfica do Design System — Archivo para UI, JetBrains Mono
/// para dado numérico/tabular. Estático (não [ThemeExtension]): tipografia
/// é identidade do produto, não do tenant — só a cor de marca varia por
/// academia no futuro, nunca a fonte.
///
/// Nenhum estilo aqui embute cor de propósito — cor vem sempre de
/// `context.colors.x` aplicado no call site (`AppTypography.bodyMedium
/// .copyWith(color: context.colors.textMuted)`), pra não duplicar variação
/// de cor dentro de cada estilo de texto.
abstract final class AppTypography {
  static const _fontFamily = 'Archivo';
  static const _monoFontFamily = 'JetBrains Mono';

  /// Título de página (ex.: "Bom dia, Admin" no topo do Dashboard).
  static const displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.02,
    height: 1.2,
  );

  /// Cabeçalho de seção/painel (ex.: "Aniversariantes do mês").
  static const titleLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.01,
    height: 1.3,
  );

  /// Cabeçalho menor — título de card, item de destaque.
  static const titleMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// Corpo de texto padrão.
  static const bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// Texto editável de campo de formulário (`AppTextField`/`AppSelect`/
  /// `AppDateField`) em telas de toque — 16px, o limiar abaixo do qual
  /// Safari/WebView em iOS faz auto-zoom da página ao focar um input
  /// (docs/27, causa raiz do problema de digitação no celular). Só usado
  /// quando `context.isTouch`; em desktop os campos continuam em
  /// [bodyMedium] — o navegador desktop não tem esse comportamento de
  /// zoom, então não há motivo pra mudar o texto lá (mantém a tela
  /// pixel-idêntica ao que já existe).
  static const inputText = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// Corpo de texto secundário/apoio (ex.: subtítulo de card, legenda).
  static const bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// Rótulo curto, versalete — eyebrow, tag de categoria, cabeçalho de tabela.
  static const labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.05,
    height: 1.3,
  );

  /// Dado numérico de destaque (ex.: valor grande de um `MetricCard`).
  /// Monoespaçado — dígitos alinham entre si, sensação de dado "instrumentado".
  static const mono = TextStyle(
    fontFamily: _monoFontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Dado numérico inline, menor (ex.: data, contagem em um badge).
  static const monoSmall = TextStyle(
    fontFamily: _monoFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
