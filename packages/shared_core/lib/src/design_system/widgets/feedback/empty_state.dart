import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';
import '../buttons/app_button.dart';

/// Variante visual de [EmptyState].
enum EmptyStateVariant {
  /// Estado vazio de verdade (ex.: "nenhum aluno cadastrado") — sempre deve
  /// carregar uma ação que resolve o vazio, nunca só uma frase.
  standard,

  /// Funcionalidade que ainda não existe (ex.: Financeiro, Agenda) — borda
  /// tracejada, tom mais discreto, mostra a sprint responsável em vez de
  /// uma ação (não há ação possível ainda).
  comingSoon,
}

/// Estado vazio do Design System. Nunca uma frase solta ("Nenhum dado.") —
/// todo [EmptyState.standard] carrega [actionLabel]/[onAction] apontando a
/// próxima ação do usuário; [EmptyState.comingSoon] existe só para
/// funcionalidade ainda não implementada, com a tag da sprint responsável.
///
/// Exemplo — lista de alunos vazia:
/// ```dart
/// EmptyState(
///   icon: AppIcons.students,
///   title: 'Nenhum aluno cadastrado',
///   actionLabel: 'Cadastrar primeiro aluno',
///   onAction: () => context.push('/alunos/novo'),
/// )
/// ```
///
/// Exemplo — placeholder de funcionalidade futura:
/// ```dart
/// EmptyState.comingSoon(
///   icon: AppIcons.finance,
///   title: 'Mensalidades vencendo',
///   description: 'Pagamentos que vencem nos próximos 7 dias.',
///   sprintTag: 'SPRINT 6 · FINANCEIRO',
/// )
/// ```
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? sprintTag;
  final EmptyStateVariant variant;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  }) : sprintTag = null,
       variant = EmptyStateVariant.standard;

  const EmptyState.comingSoon({
    super.key,
    required this.icon,
    required this.title,
    required this.sprintTag,
    this.description,
  }) : actionLabel = null,
       onAction = null,
       variant = EmptyStateVariant.comingSoon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isComingSoon = variant == EmptyStateVariant.comingSoon;

    return CustomPaint(
      // Flutter não tem borda tracejada nativa (`Border.all` só faz linha
      // sólida) — desenhada à mão aqui em vez de puxar um pacote novo só
      // pra isso. O tracejado é o sinal visual de "ainda não existe",
      // validado no mockup aprovado — não trocar por borda sólida.
      foregroundPainter: isComingSoon ? _DashedRRectPainter(color: colors.border) : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: isComingSoon ? null : Border.all(color: colors.border),
        ),
        child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Icon(icon, size: 16, color: colors.textFaint),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                color: isComingSoon ? colors.textMuted : colors.text,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                description!,
                style: AppTypography.bodySmall.copyWith(color: colors.textFaint),
              ),
            ],
            if (isComingSoon) ...[
              const SizedBox(height: AppSpacing.lg),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  child: Text(
                    sprintTag!,
                    style: AppTypography.labelSmall.copyWith(color: colors.textFaint),
                  ),
                ),
              ),
            ] else if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: actionLabel!, onPressed: onAction, variant: AppButtonVariant.secondary),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  static const _dashLength = 5.0;
  static const _gapLength = 4.0;
  static const _strokeWidth = 1.5;

  final Color color;

  const _DashedRRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const inset = _strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - _strokeWidth, size.height - _strokeWidth),
      const Radius.circular(AppRadius.lg),
    );
    final dashed = Path();
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final next = (distance + (draw ? _dashLength : _gapLength)).clamp(0, metric.length).toDouble();
        if (draw) {
          dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        }
        distance = next;
        draw = !draw;
      }
    }
    canvas.drawPath(
      dashed,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) => oldDelegate.color != color;
}
