import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_spacing.dart';

/// Linha responsiva de campos de formulário — no desktop/tablet, os campos
/// dividem a largura em colunas iguais lado a lado; no mobile, empilham em
/// uma coluna só. Não sabe nada sobre domínio: recebe qualquer lista de
/// widgets (tipicamente campos do Design System), só decide o layout.
///
/// É a peça que evita "uma coluna enorme de campos" — todo formulário do
/// produto usa isso pra agrupar 1-3 campos relacionados numa linha.
///
/// Exemplo:
/// ```dart
/// AppFormRow(children: [
///   AppTextField(label: 'CPF', ...),
///   AppTextField(label: 'RG (opcional)', ...),
/// ])
/// ```
class AppFormRow extends StatelessWidget {
  final List<Widget> children;

  const AppFormRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.length == 1 || context.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            children[i],
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}
