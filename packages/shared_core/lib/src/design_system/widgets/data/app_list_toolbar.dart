import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_spacing.dart';

/// Barra de ferramentas do topo de qualquer lista do produto — busca em
/// destaque, controles secundários (filtros, ordenação, exportação) e uma
/// ação primária claramente distinta (ex.: "Novo aluno"). Não sabe nada
/// sobre domínio: quem monta a busca/filtros/ação é a tela, o componente
/// só organiza o layout responsivo.
///
/// Desktop/tablet: busca ocupa o espaço flexível, controles secundários e
/// ação primária ficam à direita numa linha só. Mobile: busca sempre em
/// linha própria (nunca perde destaque), o resto quebra pra linha de baixo.
///
/// Exemplo:
/// ```dart
/// AppListToolbar(
///   search: AppTextField(label: 'Buscar', prefixIcon: AppIcons.search, onChanged: _aoBuscar),
///   secondaryActions: [AppSelect<UserStatus?>(...), _botaoOrdenarDesabilitado],
///   primaryAction: AppButton(label: 'Novo aluno', icon: AppIcons.add, onPressed: _criar),
/// )
/// ```
class AppListToolbar extends StatelessWidget {
  final Widget search;
  final List<Widget> secondaryActions;
  final Widget? primaryAction;

  const AppListToolbar({
    super.key,
    required this.search,
    this.secondaryActions = const [],
    this.primaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final trailing = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [...secondaryActions, ?primaryAction],
    );

    if (context.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: AppSpacing.md),
          trailing,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: search)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Align(alignment: Alignment.centerRight, child: trailing)),
      ],
    );
  }
}
