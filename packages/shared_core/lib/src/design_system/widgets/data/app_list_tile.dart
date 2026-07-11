import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';

/// Linha de lista do Design System — avatar (iniciais) + título/subtítulo +
/// trilha opcional. Usada em qualquer lista de item "pessoa/registro"
/// (aniversariantes, alunos novos hoje; alunos/professores em geral quando
/// essas telas migrarem para o Design System). Não inclui separador — quem
/// monta a lista decide (`Divider` entre itens, ou nenhum).
///
/// Exemplo:
/// ```dart
/// AppListTile(title: 'Mariana Ferreira', subtitle: 'Plano Trimestral', leadingText: 'MF', trailing: AppBadge('12/jul'))
/// ```
class AppListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String leadingText;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.leadingText,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colors.cardRaised,
            child: Text(
              leadingText,
              style: AppTypography.bodySmall.copyWith(color: colors.textMuted, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(color: colors.text),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: AppSpacing.md), trailing!],
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        hoverColor: colors.cardRaised,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: content,
        ),
      ),
    );
  }
}
