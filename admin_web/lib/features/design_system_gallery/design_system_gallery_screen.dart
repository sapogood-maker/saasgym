import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';

/// Documentação viva do Design System — não é uma tela de produto, é
/// catálogo interno pra validar visualmente cada componente antes dele
/// "entrar" no sistema. Organizada por categoria (Colors, Typography,
/// Buttons, Cards, Lists, Chips, Empty States, Skeleton, Navigation,
/// Motion); categorias sem componente construído ainda (Inputs, Forms,
/// Tables) não aparecem — entram quando o componente correspondente for
/// implementado, não antes.
///
/// Regra do projeto (vigente desde a Sprint 1, MS3): todo componente novo
/// do Design System precisa aparecer aqui — variações, estados e uma
/// documentação rápida de uso. Faz parte da definição de "pronto" de
/// qualquer componente novo, não é opcional.
class DesignSystemGalleryScreen extends StatelessWidget {
  const DesignSystemGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text('Design System — Component Gallery', style: AppTypography.titleLarge.copyWith(color: colors.text)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Section(title: 'Colors', child: _ColorsShowcase()),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(title: 'Typography', child: _TypographyShowcase()),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(title: 'Buttons', child: _ButtonsShowcase()),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(title: 'Cards', child: _CardsShowcase()),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(title: 'Lists', child: _ListsShowcase()),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(title: 'Chips', child: _ChipsShowcase()),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(title: 'Empty States', child: _EmptyStatesShowcase()),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(title: 'Skeleton', child: _SkeletonShowcase()),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(title: 'Navigation', child: _NavigationShowcase()),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(title: 'Motion', child: _MotionShowcase()),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.labelSmall.copyWith(color: colors.primary)),
        const SizedBox(height: AppSpacing.md),
        Container(height: 1, color: colors.border),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    );
  }
}

class _ColorsShowcase extends StatelessWidget {
  const _ColorsShowcase();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = <(String, Color)>[
      ('background', colors.background),
      ('surface', colors.surface),
      ('card', colors.card),
      ('border', colors.border),
      ('text', colors.text),
      ('text.muted', colors.textMuted),
      ('primary', colors.primary),
      ('success', colors.success),
      ('warning', colors.warning),
      ('error', colors.error),
      ('info', colors.info),
    ];

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final (name, color) in tokens)
          SizedBox(
            width: 140,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md - 1)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      name,
                      style: AppTypography.monoSmall.copyWith(color: colors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TypographyShowcase extends StatelessWidget {
  const _TypographyShowcase();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rows = <(String, TextStyle, String)>[
      ('displayLarge', AppTypography.displayLarge, 'Visão geral da academia'),
      ('titleLarge', AppTypography.titleLarge, 'Aniversariantes do mês'),
      ('titleMedium', AppTypography.titleMedium, 'Nenhum aluno cadastrado'),
      ('bodyMedium', AppTypography.bodyMedium, 'Admin cadastrou o aluno Rodrigo Castro.'),
      ('bodySmall', AppTypography.bodySmall, 'Plano Trimestral'),
      ('labelSmall', AppTypography.labelSmall, 'SPRINT 6 · FINANCEIRO'),
      ('mono', AppTypography.mono, '128'),
      ('monoSmall', AppTypography.monoSmall, '12/jul'),
    ];

    return Column(
      children: [
        for (final (name, style, sample) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(name, style: AppTypography.monoSmall.copyWith(color: colors.textFaint)),
                ),
                Expanded(child: Text(sample, style: style.copyWith(color: colors.text))),
              ],
            ),
          ),
      ],
    );
  }
}

class _ButtonsShowcase extends StatelessWidget {
  const _ButtonsShowcase();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppButton(label: 'Primary', onPressed: () {}),
        AppButton(label: 'Secondary', onPressed: () {}, variant: AppButtonVariant.secondary),
        AppButton(label: 'Ghost', onPressed: () {}, variant: AppButtonVariant.ghost),
        AppButton(label: 'Outline', onPressed: () {}, variant: AppButtonVariant.outline),
        AppButton(label: 'Danger', onPressed: () {}, variant: AppButtonVariant.danger),
        AppButton(label: 'Success', onPressed: () {}, variant: AppButtonVariant.success),
        AppButton(label: 'Loading', onPressed: () {}, loading: true),
        const AppButton(label: 'Disabled', onPressed: null),
        AppButton(label: 'Com ícone', onPressed: () {}, icon: AppIcons.students),
      ],
    );
  }
}

class _CardsShowcase extends StatelessWidget {
  const _CardsShowcase();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.lg,
      children: [
        SizedBox(
          width: 320,
          child: AppCard(
            title: 'Aniversariantes do mês',
            actions: [const AppBadge('4')],
            child: const Text('Mariana Ferreira · 12/jul'),
          ),
        ),
        SizedBox(
          width: 320,
          child: AppCard(
            title: 'Card carregando',
            subtitle: 'Simulação de loading',
            loading: true,
          ),
        ),
        SizedBox(
          width: 320,
          child: AppCard(
            title: 'Card com rodapé',
            footer: Text('Atualizado agora', style: AppTypography.bodySmall.copyWith(color: context.colors.textFaint)),
            child: const Text('Conteúdo principal do card.'),
          ),
        ),
        SizedBox(
          width: 320,
          child: AppCard(
            title: 'Card clicável',
            onTap: () {},
            child: const Text('Hover/click para ver o feedback.'),
          ),
        ),
      ],
    );
  }
}

class _ListsShowcase extends StatelessWidget {
  const _ListsShowcase();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 360,
      child: AppCard(
        title: 'AppListTile',
        child: Column(
          children: [
            const AppListTile(title: 'Mariana Ferreira', subtitle: 'Plano Trimestral', leadingText: 'MF', trailing: AppBadge('12/jul')),
            Divider(color: colors.borderSoft, height: 1),
            AppListTile(
              title: 'Rodrigo Castro',
              subtitle: 'Cadastrado há 2 dias',
              leadingText: 'RC',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipsShowcase extends StatelessWidget {
  const _ChipsShowcase();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppBadge('Neutro'),
        AppBadge('Marca', tone: AppBadgeTone.primary),
        AppBadge('Ativo', tone: AppBadgeTone.success),
        AppBadge('Vence em 3 dias', tone: AppBadgeTone.warning),
        AppBadge('Inadimplente', tone: AppBadgeTone.error),
        AppBadge('Novo', tone: AppBadgeTone.info),
      ],
    );
  }
}

class _EmptyStatesShowcase extends StatelessWidget {
  const _EmptyStatesShowcase();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.lg,
      children: [
        SizedBox(
          width: 320,
          child: EmptyState(
            icon: AppIcons.students,
            title: 'Nenhum aluno cadastrado',
            description: 'Cadastre o primeiro aluno para começar a usar o SaaSGym.',
            actionLabel: 'Cadastrar primeiro aluno',
            onAction: () {},
          ),
        ),
        const SizedBox(
          width: 320,
          child: EmptyState.comingSoon(
            icon: AppIcons.finance,
            title: 'Mensalidades vencendo',
            description: 'Pagamentos que vencem nos próximos 7 dias.',
            sprintTag: 'SPRINT 6 · FINANCEIRO',
          ),
        ),
      ],
    );
  }
}

class _SkeletonShowcase extends StatelessWidget {
  const _SkeletonShowcase();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LoadingSkeleton(width: 40, height: 40, shape: AppSkeletonShape.circle),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoadingSkeleton(width: 160, height: 12),
                  SizedBox(height: AppSpacing.sm),
                  LoadingSkeleton(width: 100, height: 10),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        LoadingSkeleton(width: double.infinity, height: 12),
        SizedBox(height: AppSpacing.sm),
        LoadingSkeleton(width: 280, height: 12),
      ],
    );
  }
}

class _NavigationShowcase extends StatelessWidget {
  const _NavigationShowcase();

  static const _destinos = [
    AppSidebarDestination(label: 'Dashboard', icon: AppIcons.dashboard, path: '/', section: 'Operação'),
    AppSidebarDestination(label: 'Alunos', icon: AppIcons.students, path: '/alunos', section: 'Operação'),
    AppSidebarDestination(label: 'Professores', icon: AppIcons.teachers, path: '/professores', section: 'Operação'),
    AppSidebarDestination(label: 'Financeiro', icon: AppIcons.finance, path: '/financeiro', section: 'Operação', enabled: false),
    AppSidebarDestination(label: 'Meu perfil', icon: AppIcons.profile, path: '/perfil', section: 'Conta'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AppBreadcrumb', style: AppTypography.labelSmall.copyWith(color: colors.textFaint)),
        const SizedBox(height: AppSpacing.sm),
        const AppBreadcrumb(['Dashboard']),
        const SizedBox(height: AppSpacing.xs),
        const AppBreadcrumb(['Alunos', 'Mariana Ferreira']),
        const SizedBox(height: AppSpacing.xl),
        Text('AppHeader', style: AppTypography.labelSmall.copyWith(color: colors.textFaint)),
        const SizedBox(height: AppSpacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(AppRadius.md)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md - 1),
            child: AppHeader(breadcrumb: const AppBreadcrumb(['Dashboard']), onMenuTap: () {}),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('AppSidebar', style: AppTypography.labelSmall.copyWith(color: colors.textFaint)),
        const SizedBox(height: AppSpacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(AppRadius.md)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md - 1),
            child: SizedBox(
              height: 460,
              child: AppSidebar(
                academiaNome: 'Academia Demo',
                planoNome: 'Trial',
                destinations: _destinos,
                currentPath: '/alunos',
                onDestinationSelected: (_) {},
                userNome: 'Ana Admin',
                userCargo: 'Administrador',
                onProfileTap: () {},
                onLogout: () {},
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MotionShowcase extends StatefulWidget {
  const _MotionShowcase();

  @override
  State<_MotionShowcase> createState() => _MotionShowcaseState();
}

class _MotionShowcaseState extends State<_MotionShowcase> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AppMotion.fast (120ms) / base (180ms) / slow (280ms) com AppMotion.curveStandard — clique para ver a transição base em ação.',
          style: AppTypography.bodySmall.copyWith(color: colors.textFaint),
        ),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: AnimatedContainer(
            duration: AppMotion.base,
            curve: AppMotion.curveStandard,
            width: _expanded ? 320 : 160,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primaryWash,
              border: Border.all(color: colors.primary),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text('Clique aqui', style: AppTypography.bodySmall.copyWith(color: colors.primary)),
          ),
        ),
      ],
    );
  }
}
