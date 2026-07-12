import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_icons.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';

/// Paginação do Design System — pensada para paginação de servidor (a
/// tela não tem a lista inteira em memória, só a página atual + os totais
/// que o backend retornou), não paginação de uma lista já carregada
/// localmente. Mesmo formato que `PaginatedResult` já usa hoje
/// (`page`/`pageSize`/`total`), então uma tela típica só repassa os
/// campos da resposta da API.
///
/// Exemplo:
/// ```dart
/// AppPagination(
///   page: resultado.page,
///   pageSize: resultado.pageSize,
///   total: resultado.total,
///   onPageChanged: (novaPagina) => _irParaPagina(novaPagina),
/// )
/// ```
class AppPagination extends StatelessWidget {
  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onPageChanged;

  const AppPagination({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPageChanged,
  });

  int get _totalPages => (total / pageSize).ceil().clamp(1, 1 << 31);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final totalPages = _totalPages;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepButton(
          icon: AppIcons.chevronLeft,
          enabled: page > 1,
          onTap: () => onPageChanged(page - 1),
        ),
        const SizedBox(width: AppSpacing.md),
        // Flexible + ellipsis: sem isso, o texto (largura variável conforme
        // o total) estoura o Row assim que a tela fica estreita — mesmo
        // padrão de bug já visto em AppButton/AppBreadcrumb/AppHeader.
        Flexible(
          child: Text(
            'Página $page de $totalPages · $total no total',
            style: AppTypography.monoSmall.copyWith(color: colors.textMuted),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _StepButton(
          icon: AppIcons.chevronRight,
          enabled: page < totalPages,
          onTap: () => onPageChanged(page + 1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        hoverColor: colors.cardRaised,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: enabled ? colors.textMuted : colors.textFaint),
        ),
      ),
    );
  }
}
