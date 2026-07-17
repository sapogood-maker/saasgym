import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_icons.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_shadows.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';
import '../feedback/app_badge.dart';
import '../feedback/loading_skeleton.dart';

/// Direção de tendência de [MetricCard.trend] — controla a cor/ícone da
/// linha de delta. [up]/[down] usam as cores semânticas de sucesso/erro,
/// nunca a cor de marca (tendência não é identidade visual).
enum AppMetricTrend { up, down, neutral }

/// Cartão de indicador — um número em destaque, rótulo e delta opcional.
/// Reutilizado em qualquer tela que precise de um KPI (Dashboard hoje;
/// Financeiro/Relatórios nas sprints futuras vão usar o mesmo widget).
///
/// [highlight] marca a métrica principal da tela (tratamento com a cor de
/// marca) — usar em no máximo uma métrica por tela, para não diluir o
/// destaque.
class MetricCard extends StatelessWidget {
  final String label;

  /// Valor já formatado como string — ex.: "128" ou "—" quando não há
  /// dado ainda (nunca inventar um número).
  final String value;
  final IconData? icon;
  final bool highlight;

  /// Tom semântico de urgência/estado — ex.: [AppBadgeTone.error] pra uma
  /// métrica que representa um problema (inadimplência), nunca a cor de
  /// marca (essa é só [highlight], no máximo uma métrica por tela).
  /// Tinge o chip do ícone e o valor; `null` mantém o tratamento neutro
  /// padrão. Independente de [highlight] — os dois podem coexistir, ainda
  /// que a combinação normalmente não faça sentido de produto (marca +
  /// urgência ao mesmo tempo).
  final AppBadgeTone? tone;

  final String? deltaLabel;
  final AppMetricTrend trend;
  final bool loading;

  /// Largura do card. Precisa de valor próprio (não intrínseco) porque o
  /// `Row` interno usa `spaceBetween` — sem largura fixa, o card se
  /// expande para ocupar toda a linha disponível dentro de um `Wrap`,
  /// impedindo vários cards de ficarem lado a lado.
  final double width;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.highlight = false,
    this.tone,
    this.deltaLabel,
    this.trend = AppMetricTrend.neutral,
    this.loading = false,
    this.width = 220,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final trendColor = switch (trend) {
      AppMetricTrend.up => colors.success,
      AppMetricTrend.down => colors.error,
      AppMetricTrend.neutral => colors.textFaint,
    };

    // `highlight` (marca/dourado) sempre tem prioridade sobre `tone`
    // (estado semântico) quando os dois estão setados — na prática só um
    // dos dois é usado por vez (ver doc do campo `tone`).
    final (Color? toneWash, Color? toneColor) = (highlight || tone == null)
        ? (null, null)
        : switch (tone!) {
            AppBadgeTone.neutral => (colors.cardRaised, colors.textMuted),
            AppBadgeTone.primary => (colors.primaryWash, colors.primaryStrong),
            AppBadgeTone.success => (colors.successWash, colors.success),
            AppBadgeTone.warning => (colors.warningWash, colors.warning),
            AppBadgeTone.error => (colors.errorWash, colors.error),
            AppBadgeTone.info => (colors.infoWash, colors.info),
          };

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          border: Border.all(
            color: highlight
                ? colors.primary.withValues(alpha: 0.35)
                : (toneColor?.withValues(alpha: 0.35) ?? colors.border),
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
          gradient: highlight
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.primaryWash, colors.card],
                  stops: const [0, 0.6],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Expanded + ellipsis: rótulo mais longo que o espaço
                  // sobrando (ex.: "Alunos ativos" ao lado do chip de
                  // ícone, num card de largura fixa) trunca em vez de
                  // estourar o Row — mesma defesa do AppButton/AppBreadcrumb.
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: highlight
                            ? colors.primaryWash
                            : (toneWash ?? colors.cardRaised),
                        border: Border.all(
                          color: highlight
                              ? colors.primary.withValues(alpha: 0.4)
                              : (toneColor?.withValues(alpha: 0.4) ?? colors.border),
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Icon(
                          icon,
                          size: 15,
                          color: highlight ? colors.primary : (toneColor ?? colors.textMuted),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (loading)
                const LoadingSkeleton(width: 72, height: 26)
              else
                Text(
                  value,
                  style: AppTypography.mono.copyWith(color: toneColor ?? colors.text),
                ),
              if (deltaLabel != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (trend != AppMetricTrend.neutral)
                      Icon(
                        trend == AppMetricTrend.up
                            ? AppIcons.arrowUp
                            : AppIcons.arrowDown,
                        size: 12,
                        color: trendColor,
                      ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        deltaLabel!,
                        style: AppTypography.bodySmall.copyWith(
                          color: trend == AppMetricTrend.neutral
                              ? colors.textFaint
                              : trendColor,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
