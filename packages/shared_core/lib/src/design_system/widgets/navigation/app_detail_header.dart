import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_icons.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';

/// Cabeçalho padrão de toda tela de detalhe/formulário que vive fora do
/// `ShellRoute` (docs/26) — link de volta no canto superior esquerdo,
/// acima do título, seguido do bloco de identidade da entidade (título +
/// avatar/subtítulo/badge opcionais) e da fileira de ações. Único
/// componente para as 5 entidades (Aluno, Professor, Turma, Plano,
/// Matrícula) e seus formulários — nunca uma variação por módulo.
///
/// Não decide para onde `onBack` navega — isso é responsabilidade de quem
/// usa o componente (`BuildContext.backToList` em admin_web), porque cada
/// tela tem sua própria regra de qual resultado devolver ao sair.
///
/// Exemplo:
/// ```dart
/// AppDetailHeader(
///   listLabel: 'Alunos',
///   onBack: _voltar,
///   leading: AppAvatarPicker(imageUrl: aluno.fotoUrl, radius: 40, enabled: false),
///   title: aluno.nome,
///   trailing: AppBadge('Ativo', tone: AppBadgeTone.success),
///   actions: [AppButton(label: 'Editar', onPressed: ...)],
/// )
/// ```
class AppDetailHeader extends StatelessWidget {
  const AppDetailHeader({
    required this.listLabel,
    required this.onBack,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.actions,
    super.key,
  });

  /// Rótulo da lista de origem — ex.: "Alunos". Some do "← Voltar para" por
  /// decisão de produto (docs/26): só a seta + o nome já comunica o destino.
  final String listLabel;

  final VoidCallback onBack;

  /// Avatar/ícone da entidade — opcional (Aluno/Professor têm, Turma/Plano/
  /// Matrícula não).
  final Widget? leading;

  final String title;

  /// Ex.: nome do plano na Matrícula — opcional.
  final String? subtitle;

  /// Badge de status, ao lado do título — opcional.
  final Widget? trailing;

  /// Editar/Inativar/Remover (ou o conjunto condicional da Matrícula) — a
  /// mesma fileira de botões que cada tela já monta, só passada pra cá.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.lg)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: AppTypography.displayLarge.copyWith(color: colors.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle!, style: AppTypography.bodyMedium.copyWith(color: colors.textMuted)),
              ],
            ],
          ),
        ),
      ],
    );

    final acoes = (actions == null || actions!.isEmpty)
        ? null
        : Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: actions!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppBackLink(label: listLabel, onTap: onBack),
        const SizedBox(height: AppSpacing.lg),
        if (context.isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [info, if (acoes != null) ...[const SizedBox(height: AppSpacing.lg), acoes]],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: info),
              if (acoes != null) ...[const SizedBox(width: AppSpacing.lg), acoes],
            ],
          ),
      ],
    );
  }
}

/// Link de volta isolado — o mesmo bloco usado dentro de [AppDetailHeader],
/// exposto à parte pra telas usarem nos estados de carregamento/erro (antes
/// da entidade carregar, ainda não há `title` pra montar o header inteiro,
/// mas o link de volta não depende de nenhum dado). Não é um `AppButton`
/// (é wayfinding, não uma ação primária da tela): tom discreto por padrão,
/// mais forte no hover.
class AppBackLink extends StatefulWidget {
  const AppBackLink({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  State<AppBackLink> createState() => _AppBackLinkState();
}

class _AppBackLinkState extends State<AppBackLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cor = _hover ? colors.text : colors.textMuted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        // Só padding à direita/vertical — a borda esquerda do hit-target
        // fica em x=0, alinhada com o título logo abaixo (nenhum
        // deslocamento pra compensar).
        child: Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.xs,
            bottom: AppSpacing.xs,
            right: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.chevronLeft, size: 16, color: cor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                widget.label,
                style: AppTypography.bodyMedium.copyWith(color: cor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
