import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_shadows.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';
import '../feedback/loading_skeleton.dart';

/// Superfície de conteúdo base do Design System — a peça mais usada do
/// sistema. Um único widget cobre título, subtítulo, ações, rodapé e
/// carregamento via slots opcionais, em vez de existir uma variante de
/// Card por caso de uso.
///
/// Exemplo — card de painel com contagem e link:
/// ```dart
/// AppCard(
///   title: 'Aniversariantes do mês',
///   actions: [Text('4')],
///   child: Column(children: linhas),
/// )
/// ```
class AppCard extends StatelessWidget {
  /// Título do card, exibido no topo em [AppTypography.titleLarge].
  final String? title;

  /// Subtítulo, abaixo do título, em tom secundário.
  final String? subtitle;

  /// Widgets alinhados à direita do título — ex.: contagem, link "ver tudo",
  /// botão de ação rápida.
  final List<Widget>? actions;

  /// Conteúdo principal do card.
  final Widget? child;

  /// Conteúdo do rodapé, separado do [child] por uma divisória.
  final Widget? footer;

  /// Quando true, ignora [title]/[subtitle]/[child] e mostra um esqueleto
  /// de carregamento com a mesma silhueta — usar em vez de um spinner
  /// solto, para o layout não pular quando o dado real chega.
  final bool loading;

  /// Quando definido, o card inteiro vira uma área de toque (com feedback
  /// de hover/pressed) — usar quando o card representa uma navegação.
  final VoidCallback? onTap;

  /// Nulo usa o padrão do componente — `AppSpacing.xl` (24) em desktop,
  /// `AppSpacing.lg` (16) em telas de toque (docs/27: mais espaço útil
  /// numa tela de 375px). Quem passa um valor explícito continua com esse
  /// valor em qualquer tela, sem esse ajuste automático.
  final EdgeInsetsGeometry? padding;

  const AppCard({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
    this.child,
    this.footer,
    this.loading = false,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final effectivePadding = padding ??
        EdgeInsets.all(context.isTouch ? AppSpacing.lg : AppSpacing.xl);

    final content = Padding(
      padding: effectivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || actions != null) ...[
            Row(
              children: [
                Expanded(
                  child: loading
                      ? const LoadingSkeleton(width: 160, height: 16)
                      : Text(title ?? '', style: AppTypography.titleLarge.copyWith(color: colors.text)),
                ),
                if (!loading && actions != null) ...actions!,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              loading
                  ? const LoadingSkeleton(width: 220, height: 12)
                  : Text(subtitle!, style: AppTypography.bodySmall.copyWith(color: colors.textMuted)),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
          if (loading)
            const _CardSkeletonBody()
          else
            ?child,
          if (footer != null) ...[
            SizedBox(height: AppSpacing.lg),
            Divider(color: colors.borderSoft, height: 1),
            SizedBox(height: AppSpacing.md),
            footer!,
          ],
        ],
      ),
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: content,
    );

    if (onTap == null) return decorated;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: colors.cardRaised.withValues(alpha: 0.6),
        splashColor: colors.cardRaised,
        child: decorated,
      ),
    );
  }
}

/// Corpo padrão do esqueleto de [AppCard] quando `loading: true` e nenhum
/// [AppCard.child] específico precisa ser simulado — algumas linhas de
/// largura variável, parecendo um parágrafo/lista curta.
class _CardSkeletonBody extends StatelessWidget {
  const _CardSkeletonBody();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LoadingSkeleton(width: double.infinity, height: 12),
        SizedBox(height: AppSpacing.sm),
        LoadingSkeleton(width: 260, height: 12),
        SizedBox(height: AppSpacing.sm),
        LoadingSkeleton(width: 180, height: 12),
      ],
    );
  }
}
