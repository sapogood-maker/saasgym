import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_icons.dart';
import '../../tokens/app_motion.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';

/// Um item de navegação do [AppSidebar].
///
/// [section] agrupa itens sob um rótulo (ex.: "Operação"/"Conta") — itens
/// consecutivos com o mesmo [section] ficam juntos, sem repetir o rótulo.
/// [enabled] = false mostra o item visível porém inerte, para funcionalidade
/// que ainda não existe (ex.: Agenda/Financeiro antes das sprints
/// correspondentes) — sinaliza "vem por aí" sem esconder da navegação.
class AppSidebarDestination {
  final String label;
  final IconData icon;
  final String path;
  final String? section;
  final bool enabled;

  const AppSidebarDestination({
    required this.label,
    required this.icon,
    required this.path,
    this.section,
    this.enabled = true,
  });
}

/// Sidebar premium do Shell — a peça que o usuário olha o dia inteiro.
/// Puramente apresentacional (recebe todo dado pronto via parâmetro): quem
/// monta a tela decide de onde vem `academiaNome`/`userNome`/rotas, o
/// widget só sabe desenhar. Isso é o que permite mostrar no Component
/// Gallery com dado fake, sem precisar de sessão/API real.
class AppSidebar extends StatelessWidget {
  final String academiaNome;
  final String? planoNome;
  final List<AppSidebarDestination> destinations;
  final String currentPath;
  final ValueChanged<String> onDestinationSelected;
  final String userNome;
  final String userCargo;
  final VoidCallback onProfileTap;
  final VoidCallback onLogout;

  const AppSidebar({
    super.key,
    required this.academiaNome,
    this.planoNome,
    required this.destinations,
    required this.currentPath,
    required this.onDestinationSelected,
    required this.userNome,
    required this.userCargo,
    required this.onProfileTap,
    required this.onLogout,
  });

  bool _isSelected(String path) {
    if (path == '/') return currentPath == '/';
    return currentPath == path || currentPath.startsWith('$path/');
  }

  List<Widget> _buildNavItems() {
    final items = <Widget>[];
    String? lastSection;
    for (final destination in destinations) {
      if (destination.section != lastSection) {
        items.add(_SectionLabel(destination.section ?? ''));
        lastSection = destination.section;
      }
      items.add(
        _NavItem(
          destination: destination,
          selected: _isSelected(destination.path),
          onTap: destination.enabled ? () => onDestinationSelected(destination.path) : null,
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: Column(
        children: [
          _Brand(academiaNome: academiaNome, planoNome: planoNome),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: _buildNavItems(),
            ),
          ),
          _UserFooter(
            userNome: userNome,
            userCargo: userCargo,
            onProfileTap: onProfileTap,
            onLogout: onLogout,
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final String academiaNome;
  final String? planoNome;

  const _Brand({required this.academiaNome, this.planoNome});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.cardRaised,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                academiaNome.isNotEmpty ? academiaNome[0].toUpperCase() : '?',
                style: AppTypography.mono.copyWith(color: colors.primary, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  academiaNome,
                  style: AppTypography.titleMedium.copyWith(color: colors.text),
                  overflow: TextOverflow.ellipsis,
                ),
                if (planoNome != null)
                  Text(
                    'Plano $planoNome',
                    style: AppTypography.bodySmall.copyWith(color: colors.textFaint),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox(height: AppSpacing.sm);
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.lg, AppSpacing.sm, AppSpacing.sm),
      child: Text(label, style: AppTypography.labelSmall.copyWith(color: colors.textFaint)),
    );
  }
}

class _NavItem extends StatefulWidget {
  final AppSidebarDestination destination;
  final bool selected;
  final VoidCallback? onTap;

  const _NavItem({required this.destination, required this.selected, required this.onTap});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final destination = widget.destination;
    final disabled = widget.onTap == null;

    final Color background = widget.selected
        ? colors.primaryWash
        : _hovered
        ? colors.cardRaised
        : Colors.transparent;
    final Color foreground = disabled
        ? colors.textFaint.withValues(alpha: 0.6)
        : widget.selected
        ? colors.primaryStrong
        : colors.textMuted;

    final content = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.curveStandard,
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            margin: const EdgeInsets.only(right: AppSpacing.sm - 3),
            decoration: BoxDecoration(
              color: widget.selected ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            // Docs/27: linha do item de navegação sobe de ~35px pra ~45px
            // em telas de toque (relevante sobretudo dentro do `Drawer`
            // mobile) — desktop mantém o padding original.
            padding: EdgeInsets.symmetric(
              vertical: context.isTouch ? AppSpacing.lg - 2 : AppSpacing.sm + 1,
            ),
            child: Icon(destination.icon, size: 17, color: foreground),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              destination.label,
              style: AppTypography.bodyMedium.copyWith(color: foreground, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (disabled)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text('em breve', style: AppTypography.labelSmall.copyWith(color: colors.textFaint, letterSpacing: 0)),
            ),
        ],
      ),
    );

    if (disabled) {
      return Tooltip(message: '${destination.label} — ainda não disponível', child: content);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          hoverColor: Colors.transparent,
          child: content,
        ),
      ),
    );
  }
}

class _UserFooter extends StatelessWidget {
  final String userNome;
  final String userCargo;
  final VoidCallback onProfileTap;
  final VoidCallback onLogout;

  const _UserFooter({
    required this.userNome,
    required this.userCargo,
    required this.onProfileTap,
    required this.onLogout,
  });

  String get _initials {
    final parts = userNome.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: PopupMenuButton<_ProfileAction>(
          tooltip: 'Menu do usuário',
          offset: const Offset(0, -8),
          color: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: colors.border),
          ),
          onSelected: (action) => switch (action) {
            _ProfileAction.profile => onProfileTap(),
            _ProfileAction.logout => onLogout(),
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _ProfileAction.profile,
              child: Text('Meu perfil', style: AppTypography.bodyMedium.copyWith(color: colors.text)),
            ),
            PopupMenuItem(
              value: _ProfileAction.logout,
              child: Text('Sair', style: AppTypography.bodyMedium.copyWith(color: colors.error)),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: colors.cardRaised,
                  child: Text(_initials, style: AppTypography.bodySmall.copyWith(color: colors.text, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(userNome, style: AppTypography.bodySmall.copyWith(color: colors.text, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                      Text(userCargo, style: AppTypography.bodySmall.copyWith(color: colors.textFaint), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(AppIcons.chevronDown, size: 14, color: colors.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ProfileAction { profile, logout }
