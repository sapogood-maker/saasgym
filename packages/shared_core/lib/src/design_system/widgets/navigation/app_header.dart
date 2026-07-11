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
/// Busca e notificações ainda não têm funcionalidade real por trás (sem
/// backend de busca/notificação hoje) — os dois são propositalmente
/// "burros" (abrem um popover de estado vazio), preparados para ganhar
/// comportamento real numa sprint futura sem mudar a composição do header.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  /// Normalmente um [AppBreadcrumb].
  final Widget? breadcrumb;

  /// Quando definido, mostra o botão de menu (abre o Drawer no mobile).
  final VoidCallback? onMenuTap;

  const AppHeader({super.key, this.breadcrumb, this.onMenuTap});

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
          const _NotificationsButton(),
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
            padding: const EdgeInsets.all(AppSpacing.sm),
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
  const _NotificationsButton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        hoverColor: colors.cardRaised,
        onTap: () => _showComingSoonPopover(
          context,
          icon: AppIcons.bell,
          title: 'Notificações',
          sprintTag: 'EM DESENVOLVIMENTO',
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(AppIcons.bell, size: 18, color: colors.textMuted),
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
