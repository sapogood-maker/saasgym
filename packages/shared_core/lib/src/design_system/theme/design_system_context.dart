import 'package:flutter/material.dart';
import '../tokens/app_breakpoints.dart';
import '../tokens/app_colors.dart';

/// Acesso ergonômico aos tokens do Design System a partir de qualquer
/// [BuildContext]. Preferir sempre `context.colors.x` a
/// `Theme.of(context).extension<AppColorScheme>()!.x` por extenso.
extension DesignSystemContext on BuildContext {
  /// Paleta de cores ativa — hoje sempre [AppColorScheme.darkPremium].
  AppColorScheme get colors => Theme.of(this).extension<AppColorScheme>()!;

  /// true quando a largura da tela está abaixo de [AppBreakpoints.mobile].
  bool get isMobile => MediaQuery.sizeOf(this).width < AppBreakpoints.mobile;

  /// true quando a largura da tela está entre [AppBreakpoints.mobile] e
  /// [AppBreakpoints.tablet].
  bool get isTablet {
    final width = MediaQuery.sizeOf(this).width;
    return width >= AppBreakpoints.mobile && width < AppBreakpoints.tablet;
  }

  /// true quando a largura da tela está em [AppBreakpoints.tablet] ou acima.
  bool get isDesktop => MediaQuery.sizeOf(this).width >= AppBreakpoints.tablet;
}
