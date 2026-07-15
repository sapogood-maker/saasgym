import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_colors.dart';
import '../../tokens/app_icons.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';
import '../feedback/empty_state.dart';

/// Barra superior do Shell — vive ao lado do [AppSidebar], nunca sozinha
/// numa tela (para isso, usar `AppBar` comum). Composição fixa: menu
/// (mobile) → [breadcrumb] → busca global (placeholder) → notificações.
///
/// Busca continua sem funcionalidade real (sem backend de busca hoje) —
/// propositalmente "burra" (abre um popover de estado vazio). Notificações
/// ganhou dado real na Sprint 6 (MS4): o Design System só sabe exibir a
/// contagem e delegar o toque (`onNotificationsTap`) — buscar/renderizar a
/// lista de verdade é responsabilidade de quem usa o header (admin_web),
/// nunca do pacote de Design System (sem dependência de API aqui).
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  /// Normalmente um [AppBreadcrumb].
  final Widget? breadcrumb;

  /// Quando definido, mostra o botão de menu (abre o Drawer no mobile).
  final VoidCallback? onMenuTap;

  /// Total de notificações não lidas — badge no sino. Zero/nulo não mostra
  /// nada (mesmo padrão de "nulo = sem contagem" já usado em
  /// `capacidadeMaxima`/`quantidadeAulas`).
  final int notificacoesNaoLidas;

  /// Quando definido, substitui o popover "em desenvolvimento" padrão —
  /// quem usa o header decide o que acontece ao tocar no sino.
  final VoidCallback? onNotificationsTap;

  const AppHeader({
    super.key,
    this.breadcrumb,
    this.onMenuTap,
    this.notificacoesNaoLidas = 0,
    this.onNotificationsTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Em telas estreitas a busca de 260px não cabe ao lado do menu +
    // breadcrumb + notificações — vira só um ícone (o mesmo padrão do
    // Drawer da sidebar: no celular, degrada graciosamente, não busca
    // paridade pixel a pixel com o desktop).
    final compactSearch = context.isMobile;

    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (onMenuTap case final onMenuTap?) ...[
            _HeaderIconButton(icon: AppIcons.menu, onTap: onMenuTap, tooltip: 'Menu'),
            const SizedBox(width: AppSpacing.md),
          ],
          // Expanded (não Flexible+Spacer): dá ao breadcrumb exatamente o
          // espaço sobrando depois dos botões, sem disputa de flex entre
          // dois widgets flexíveis — mais previsível em telas estreitas.
          Expanded(child: breadcrumb ?? const SizedBox.shrink()),
          const SizedBox(width: AppSpacing.md),
          if (compactSearch)
            _HeaderIconButton(
              icon: AppIcons.search,
              tooltip: 'Buscar',
              onTap: () => _showComingSoonPopover(context, icon: AppIcons.search, title: 'Busca global', sprintTag: 'EM DESENVOLVIMENTO'),
            )
          else
            const _GlobalSearchPlaceholder(),
          const SizedBox(width: AppSpacing.md),
          _NotificationsButton(naoLidas: notificacoesNaoLidas, onTap: onNotificationsTap),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _HeaderIconButton({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          hoverColor: colors.cardRaised,
          child: Padding(
            // Docs/27: 44×44 em telas de toque (era 34×34 fixo); desktop
            // mantém o padding original.
            padding: EdgeInsets.all(context.isTouch ? AppSpacing.lg - 3 : AppSpacing.sm),
            child: Icon(icon, size: 18, color: colors.textMuted),
          ),
        ),
      ),
    );
  }
}

/// Busca global — placeholder visual e arquitetural. Sem índice de busca no
/// backend hoje; ao tocar, mostra um estado vazio honesto em vez de fingir
/// que busca (nunca simular resultado falso).
class _GlobalSearchPlaceholder extends StatelessWidget {
  const _GlobalSearchPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        hoverColor: colors.cardRaised,
        onTap: () => _showComingSoonPopover(
          context,
          icon: AppIcons.search,
          title: 'Busca global',
          sprintTag: 'EM DESENVOLVIMENTO',
        ),
        child: Container(
          width: 260,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Icon(AppIcons.search, size: 15, color: colors.textFaint),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Buscar aluno, professor…',
                  style: AppTypography.bodySmall.copyWith(color: colors.textFaint),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _KeyHint(label: '/', colors: colors),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  final int naoLidas;
  final VoidCallback? onTap;

  const _NotificationsButton({required this.naoLidas, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: 'Notificações',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          hoverColor: colors.cardRaised,
          onTap: onTap ??
              () => _showComingSoonPopover(
                    context,
                    icon: AppIcons.bell,
                    title: 'Notificações',
                    sprintTag: 'EM DESENVOLVIMENTO',
                  ),
          child: Padding(
            // Docs/27: 44×44 em telas de toque (era 34×34 fixo); desktop
            // mantém o padding original.
            padding: EdgeInsets.all(context.isTouch ? AppSpacing.lg - 3 : AppSpacing.sm),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(AppIcons.bell, size: 18, color: colors.textMuted),
                if (naoLidas > 0)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: colors.error, shape: BoxShape.circle),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        child: Text(
                          naoLidas > 9 ? '9+' : '$naoLidas',
                          style: AppTypography.monoSmall.copyWith(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyHint extends StatelessWidget {
  final String label;
  final AppColorScheme colors;

  const _KeyHint({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Text(
          label,
          style: AppTypography.monoSmall.copyWith(color: colors.textFaint, fontSize: 10.5),
        ),
      ),
    );
  }
}

void _showComingSoonPopover(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String sprintTag,
}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SizedBox(
        width: 320,
        child: EmptyState.comingSoon(
          icon: icon,
          title: title,
          description: 'Ainda não disponível nesta versão do SaaSGym.',
          sprintTag: sprintTag,
        ),
      ),
    ),
  );
}
