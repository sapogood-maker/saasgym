import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';

/// Par rótulo/valor somente leitura — usado em painéis de detalhe (ex.:
/// `AlunoDetailScreen`) dentro de um [AppFormRow], pro grid de leitura
/// "rimar" visualmente com o grid do formulário de edição da mesma
/// entidade. Não sabe nada sobre domínio: rótulo e valor vêm de quem usa.
///
/// Exemplo:
/// ```dart
/// AppFormRow(children: [
///   AppDetailRow(label: 'Nome', value: aluno.nome),
///   AppDetailRow(label: 'CPF', value: aluno.cpf),
/// ])
/// ```
class AppDetailRow extends StatelessWidget {
  final String label;
  final String? value;

  const AppDetailRow({super.key, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasValue = value != null && value!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.bodySmall.copyWith(color: colors.textMuted)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          hasValue ? value! : '—',
          style: AppTypography.bodyMedium.copyWith(color: hasValue ? colors.text : colors.textFaint),
        ),
      ],
    );
  }
}
