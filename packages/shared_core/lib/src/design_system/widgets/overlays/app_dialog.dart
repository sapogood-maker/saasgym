import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';

/// Abre um diálogo de ação/formulário do produto — decide sozinho entre o
/// modal centralizado de desktop (comportamento inalterado, mesma casca de
/// sempre) e um bottom sheet full-width em telas de toque (docs/27, MS3:
/// nenhum diálogo do produto usava o padrão nativo de mobile antes desta
/// sprint). Único ponto de abertura pra esse tipo de diálogo — nenhuma tela
/// chama `showDialog`/`showModalBottomSheet` direto pra isso.
///
/// [builder] devolve só o **conteúdo** do diálogo (título, campos, botões)
/// — nunca embrulha em `Dialog`/`ConstrainedBox` por conta própria; a casca
/// (cartão, borda, padding, largura máxima em desktop / full-width em
/// toque) é sempre aplicada aqui, uma vez só, pra nunca variar por tela.
///
/// Exemplo:
/// ```dart
/// final criado = await showAppDialog<bool>(
///   context,
///   maxWidth: 420,
///   builder: (_) => const _NovaModalidadeDialog(),
/// );
/// ```
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 460,
}) {
  if (context.isTouch) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AppBottomSheetChrome(child: Builder(builder: builder)),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => _AppDialogChrome(maxWidth: maxWidth, child: Builder(builder: builder)),
  );
}

/// Casca de desktop — idêntica, pixel a pixel, ao `Dialog` que cada
/// diálogo do produto montava por conta própria antes desta sprint.
class _AppDialogChrome extends StatelessWidget {
  const _AppDialogChrome({required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          // `SingleChildScrollView`: alguns diálogos (formulários com muitos
          // campos) já precisavam disso pra não estourar em telas baixas —
          // centralizado aqui em vez de decidido por diálogo, pra nenhum
          // esquecer. Sem efeito visual quando o conteúdo já cabe.
          child: SingleChildScrollView(child: child),
        ),
      ),
    );
  }
}

/// Casca de toque — full-width, cantos arredondados só no topo, alça de
/// arraste visual e respiro pra área segura do sistema (notch/gestos),
/// mais o teclado somado ao padding inferior quando um campo de texto está
/// focado — o padrão nativo de bottom sheet que o produto não usava em
/// lugar nenhum antes desta sprint (docs/27, achado 6).
class _AppBottomSheetChrome extends StatelessWidget {
  const _AppBottomSheetChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final teclado = MediaQuery.viewInsetsOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.sm,
            bottom: AppSpacing.xl + teclado,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
