import 'package:flutter/material.dart';

/// Paleta de cores do SaaSGym — "Dark Premium". Nomeada por papel, nunca
/// por valor (`primary`, não `gold`) e exposta como [ThemeExtension], não
/// como classe de constantes estáticas: é isso que permite, no futuro,
/// cada academia carregar sua própria instância (logo, cor primária,
/// secundária) sem alterar nenhum widget que já consome `context.colors`.
///
/// Hoje só existe uma instância — [AppColorScheme.darkPremium]. Dark é o
/// único tema do produto por decisão de produto (não uma limitação técnica).
@immutable
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  /// Fundo principal da aplicação, atrás de tudo.
  final Color background;

  /// Camada intermediária — sidebar, topbar, campo de formulário.
  final Color surface;

  /// Fundo de cards e painéis de conteúdo.
  final Color card;

  /// Variante de [card] para hover/estado elevado.
  final Color cardRaised;

  /// Borda padrão — contorno de card, input, separador visível.
  final Color border;

  /// Borda mais discreta que [border] — divisória interna de lista/linha.
  final Color borderSoft;

  /// Texto principal — títulos e corpo de maior ênfase.
  final Color text;

  /// Texto secundário — rótulo, subtítulo, texto de apoio.
  final Color textMuted;

  /// Texto de menor ênfase — placeholder, timestamp, dado desabilitado.
  final Color textFaint;

  /// Cor de marca (dourado fosco/champagne). Só em pontos de destaque —
  /// métrica principal, item de navegação ativo, botão primário. Nunca usar
  /// como substituto de uma cor semântica (ver [success]/[warning]/[error]).
  final Color primary;

  /// Variante clara de [primary] — hover/estado de foco sobre marca.
  final Color primaryStrong;

  /// Fundo tingido com [primary] em baixa intensidade — chip/ícone com
  /// destaque de marca sem usar a cor sólida.
  final Color primaryWash;

  /// Cor de texto/ícone sobre um preenchimento sólido de [primary] (ex.:
  /// texto do botão primário) — precisa de bom contraste sobre dourado.
  final Color primaryInk;

  /// Estado de sucesso/positivo — ex.: status "ativo", tendência de alta.
  /// Nunca usar como cor de marca.
  final Color success;

  /// Fundo tingido de [success], para chip/badge de estado positivo.
  final Color successWash;

  /// Estado de alerta — ex.: "vence em breve".
  final Color warning;

  /// Fundo tingido de [warning].
  final Color warningWash;

  /// Estado de erro/crítico — ex.: "inadimplente".
  final Color error;

  /// Fundo tingido de [error].
  final Color errorWash;

  /// Estado informativo neutro — ex.: "novo".
  final Color info;

  /// Fundo tingido de [info].
  final Color infoWash;

  const AppColorScheme({
    required this.background,
    required this.surface,
    required this.card,
    required this.cardRaised,
    required this.border,
    required this.borderSoft,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.primary,
    required this.primaryStrong,
    required this.primaryWash,
    required this.primaryInk,
    required this.success,
    required this.successWash,
    required this.warning,
    required this.warningWash,
    required this.error,
    required this.errorWash,
    required this.info,
    required this.infoWash,
  });

  /// Único tema hoje. Valores validados no mockup visual aprovado
  /// (artifact "dark-premium-v2") — não ajustar sem repetir essa validação.
  factory AppColorScheme.darkPremium() => const AppColorScheme(
    background: Color(0xFF0B0B0B),
    surface: Color(0xFF131313),
    card: Color(0xFF1A1A1A),
    cardRaised: Color(0xFF202020),
    border: Color(0xFF262626),
    borderSoft: Color(0xFF1E1E1E),
    text: Color(0xFFF4F3F0),
    textMuted: Color(0xFF9A9A96),
    textFaint: Color(0xFF5C5C58),
    primary: Color(0xFFC9A96A),
    primaryStrong: Color(0xFFDDC084),
    primaryWash: Color(0xFF211C10),
    primaryInk: Color(0xFF14110A),
    success: Color(0xFF4E9F73),
    successWash: Color(0xFF142218),
    warning: Color(0xFFC9822F),
    warningWash: Color(0xFF241A0F),
    error: Color(0xFFD9594A),
    errorWash: Color(0xFF241512),
    info: Color(0xFF5C8FC4),
    infoWash: Color(0xFF121A24),
  );

  @override
  AppColorScheme copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? cardRaised,
    Color? border,
    Color? borderSoft,
    Color? text,
    Color? textMuted,
    Color? textFaint,
    Color? primary,
    Color? primaryStrong,
    Color? primaryWash,
    Color? primaryInk,
    Color? success,
    Color? successWash,
    Color? warning,
    Color? warningWash,
    Color? error,
    Color? errorWash,
    Color? info,
    Color? infoWash,
  }) {
    return AppColorScheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      cardRaised: cardRaised ?? this.cardRaised,
      border: border ?? this.border,
      borderSoft: borderSoft ?? this.borderSoft,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      primary: primary ?? this.primary,
      primaryStrong: primaryStrong ?? this.primaryStrong,
      primaryWash: primaryWash ?? this.primaryWash,
      primaryInk: primaryInk ?? this.primaryInk,
      success: success ?? this.success,
      successWash: successWash ?? this.successWash,
      warning: warning ?? this.warning,
      warningWash: warningWash ?? this.warningWash,
      error: error ?? this.error,
      errorWash: errorWash ?? this.errorWash,
      info: info ?? this.info,
      infoWash: infoWash ?? this.infoWash,
    );
  }

  @override
  AppColorScheme lerp(ThemeExtension<AppColorScheme>? other, double t) {
    if (other is! AppColorScheme) return this;
    return AppColorScheme(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardRaised: Color.lerp(cardRaised, other.cardRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryStrong: Color.lerp(primaryStrong, other.primaryStrong, t)!,
      primaryWash: Color.lerp(primaryWash, other.primaryWash, t)!,
      primaryInk: Color.lerp(primaryInk, other.primaryInk, t)!,
      success: Color.lerp(success, other.success, t)!,
      successWash: Color.lerp(successWash, other.successWash, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningWash: Color.lerp(warningWash, other.warningWash, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorWash: Color.lerp(errorWash, other.errorWash, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoWash: Color.lerp(infoWash, other.infoWash, t)!,
    );
  }
}
