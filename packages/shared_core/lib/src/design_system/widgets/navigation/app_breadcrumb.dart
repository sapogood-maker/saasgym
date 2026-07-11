import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_icons.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';

/// Trilha de navegação — hoje o Shell só produz trilhas de 1 nível (ex.:
/// `['Dashboard']`), já que as telas de detalhe/formulário ficam fora do
/// `ShellRoute` (`app_router.dart`). Pensado para crescer sem mudar a API:
/// quando uma rota aninhada entrar no shell (ex.: `Alunos / Mariana
/// Ferreira`), basta passar mais de um segmento.
///
/// Exemplo:
/// ```dart
/// AppBreadcrumb(['Alunos', 'Mariana Ferreira'])
/// ```
class AppBreadcrumb extends StatelessWidget {
  final List<String> segments;

  const AppBreadcrumb(this.segments, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(AppIcons.chevronRight, size: 12, color: colors.textFaint),
            const SizedBox(width: AppSpacing.xs),
          ],
          // Flexible + ellipsis: o header pode dar menos espaço do que o
          // segmento precisa (ex.: tela estreita) — trunca em vez de
          // estourar o Row, igual ao AppButton com rótulo longo.
          Flexible(
            child: Text(
              segments[i],
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: i == segments.length - 1 ? colors.text : colors.textFaint,
                fontWeight: i == segments.length - 1 ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
