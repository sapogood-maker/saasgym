import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';

/// Documentação viva do Design System — não é uma tela de produto, é
/// catálogo interno pra validar visualmente cada componente antes dele
/// "entrar" no sistema. Organizada por categoria (Colors, Typography,
/// Buttons, Cards, Lists, Chips, Empty States, Skeleton, Inputs, Forms,
/// Dialogs, Navigation, Motion); categorias sem componente construído ainda
/// (Tables) não aparecem — entram quando o componente correspondente for
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
              const _Section(
                title: 'Colors',
                description: 'Paleta Dark Premium — tokens nomeados por papel, nunca hex direto na tela.',
                child: _ColorsShowcase(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(
                title: 'Typography',
                description: 'Escala Archivo (UI) + JetBrains Mono (dados) — cor sempre aplicada no ponto de uso, nunca embutida no token.',
                child: _TypographyShowcase(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(
                title: 'Buttons',
                description: 'AppButton — variantes, estados de loading/disabled e ícone opcional. Único botão do produto, nunca ElevatedButton/TextButton cru.',
                child: _ButtonsShowcase(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(
                title: 'Cards',
                description: 'AppCard (superfície de conteúdo genérica) e MetricCard (indicador/KPI) — o mesmo MetricCard do Dashboard servirá Financeiro e Relatórios.',
                child: _CardsShowcase(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(
                title: 'Lists',
                description: 'AppListToolbar (busca+filtros+ação primária), AppListTile (item de lista) e AppDetailRow (par rótulo/valor somente leitura, usado nos painéis de detalhe).',
                child: _ListsShowcase(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(
                title: 'Chips',
                description: 'AppBadge — status e contadores curtos. Tom semântico (success/warning/error/info) nunca substitui a cor de marca.',
                child: _ChipsShowcase(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(
                title: 'Empty States',
                description: 'EmptyState (vazio acionável, com próximo passo) e EmptyState.comingSoon (funcionalidade ainda não implementada, com a tag da sprint responsável).',
                child: _EmptyStatesShowcase(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(
                title: 'Skeleton',
                description: 'LoadingSkeleton — placeholder de carregamento com shimmer, respeita redução de movimento do sistema.',
                child: _SkeletonShowcase(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(
                title: 'Inputs',
                description: 'AppTextField, AppSelect, AppDateField, AppAvatarPicker — mesmo chassi de validação (borda vermelha + mensagem + ícone), nenhum sabe de regra de domínio.',
                child: _InputsShowcase(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(
                title: 'Forms',
                description: 'AppFormRow (grid responsivo: 2 colunas desktop, 1 mobile) e AppFormErrorBanner (erro de formulário — nunca SnackBar).',
                child: _FormsShowcase(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(
                title: 'Dialogs',
                description: 'AppConfirmDialog — único diálogo de decisão do produto (nunca AlertDialog cru), 5 variantes de tom.',
                child: _DialogsShowcase(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(
                title: 'Navigation',
                description: 'AppBreadcrumb, AppHeader, AppSidebar e AppPagination (paginação server-side: page/total/pageSize).',
                child: _NavigationShowcase(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _Section(
                title: 'Motion',
                description: 'AppMotion — durações e curva padrão de toda transição do produto, sempre respeitando MediaQuery.disableAnimations.',
                child: _MotionShowcase(),
              ),
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
  final String description;
  final Widget child;

  const _Section({required this.title, required this.description, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.labelSmall.copyWith(color: colors.primary)),
        const SizedBox(height: AppSpacing.xs),
        Text(description, style: AppTypography.bodySmall.copyWith(color: colors.textFaint)),
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
      ('labelSmall', AppTypography.labelSmall, 'MÓDULO 3 · FINANCEIRO'),
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
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AppCard', style: AppTypography.labelSmall.copyWith(color: colors.textFaint)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
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
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('MetricCard', style: AppTypography.labelSmall.copyWith(color: colors.textFaint)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            const MetricCard(label: 'Alunos ativos', value: '128', icon: AppIcons.students),
            const MetricCard(
              label: 'Novos no mês',
              value: '12',
              icon: AppIcons.newStudent,
              deltaLabel: '+8% vs. mês anterior',
              trend: AppMetricTrend.up,
              highlight: true,
            ),
            const MetricCard(
              label: 'Inadimplência',
              value: '4',
              icon: AppIcons.finance,
              deltaLabel: '-2 vs. semana anterior',
              trend: AppMetricTrend.down,
            ),
            const MetricCard(label: 'Carregando', value: '—', loading: true),
          ],
        ),
      ],
    );
  }
}

class _ListsShowcase extends StatefulWidget {
  const _ListsShowcase();

  @override
  State<_ListsShowcase> createState() => _ListsShowcaseState();
}

class _ListsShowcaseState extends State<_ListsShowcase> {
  UserStatus? _status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AppListToolbar', style: AppTypography.labelSmall.copyWith(color: colors.textFaint)),
        const SizedBox(height: AppSpacing.sm),
        AppListToolbar(
          search: AppTextField(label: 'Buscar', hintText: 'Nome, CPF ou telefone', prefixIcon: AppIcons.search),
          secondaryActions: [
            SizedBox(
              width: 160,
              child: AppSelect<UserStatus?>(
                label: 'Status',
                value: _status,
                options: const [
                  AppSelectOption(value: null, label: 'Todos'),
                  AppSelectOption(value: UserStatus.ativo, label: 'Ativos'),
                ],
                onChanged: (v) => setState(() => _status = v),
              ),
            ),
          ],
          primaryAction: AppButton(label: 'Novo aluno', icon: AppIcons.add, onPressed: () {}),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('AppListTile', style: AppTypography.labelSmall.copyWith(color: colors.textFaint)),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
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
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('AppDetailRow (leitura, dentro de AppFormRow)', style: AppTypography.labelSmall.copyWith(color: colors.textFaint)),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: 480,
          child: AppCard(
            title: 'Dados pessoais',
            child: Column(
              children: [
                AppFormRow(children: [
                  AppDetailRow(label: 'Nome', value: 'Mariana Ferreira'),
                  AppDetailRow(label: 'CPF', value: '111.444.777-35'),
                ]),
                const SizedBox(height: AppSpacing.md),
                AppFormRow(children: [
                  AppDetailRow(label: 'RG (opcional, vazio)', value: null),
                ]),
              ],
            ),
          ),
        ),
      ],
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
            sprintTag: 'MÓDULO 3 · FINANCEIRO',
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

class _InputsShowcase extends StatefulWidget {
  const _InputsShowcase();

  @override
  State<_InputsShowcase> createState() => _InputsShowcaseState();
}

class _InputsShowcaseState extends State<_InputsShowcase> {
  UserStatus? _status;
  DateTime? _data;
  final _cpfComErroController = TextEditingController(text: '111.444.777');

  @override
  void dispose() {
    _cpfComErroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.lg,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        SizedBox(
          width: 260,
          child: AppTextField(label: 'Nome', hintText: 'Nome completo', prefixIcon: AppIcons.students),
        ),
        SizedBox(
          width: 260,
          child: AppTextField(
            label: 'CPF',
            controller: _cpfComErroController,
            validator: (_) => 'CPF inválido',
            autovalidateMode: AutovalidateMode.always,
          ),
        ),
        SizedBox(
          width: 260,
          child: AppSelect<UserStatus?>(
            label: 'Status',
            value: _status,
            options: const [
              AppSelectOption(value: null, label: 'Todos'),
              AppSelectOption(value: UserStatus.ativo, label: 'Ativos'),
              AppSelectOption(value: UserStatus.inativo, label: 'Inativos'),
            ],
            onChanged: (v) => setState(() => _status = v),
          ),
        ),
        SizedBox(
          width: 260,
          child: AppDateField(
            label: 'Data de nascimento',
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
            value: _data,
            onChanged: (v) => setState(() => _data = v),
          ),
        ),
        Column(
          children: [
            const AppAvatarPicker(),
            const SizedBox(height: AppSpacing.xs),
            Text('Vazio', style: AppTypography.labelSmall.copyWith(color: context.colors.textFaint)),
          ],
        ),
        Column(
          children: [
            const AppAvatarPicker(loading: true),
            const SizedBox(height: AppSpacing.xs),
            Text('Enviando', style: AppTypography.labelSmall.copyWith(color: context.colors.textFaint)),
          ],
        ),
        Column(
          children: [
            const AppAvatarPicker(enabled: false),
            const SizedBox(height: AppSpacing.xs),
            Text('Somente leitura', style: AppTypography.labelSmall.copyWith(color: context.colors.textFaint)),
          ],
        ),
      ],
    );
  }
}

class _FormsShowcase extends StatelessWidget {
  const _FormsShowcase();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AppFormRow (2 campos — vira 1 coluna no mobile)', style: AppTypography.labelSmall.copyWith(color: context.colors.textFaint)),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: 500,
          child: AppFormRow(
            children: [
              AppTextField(label: 'CPF', hintText: '000.000.000-00'),
              AppTextField(label: 'RG (opcional)'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('AppFormErrorBanner', style: AppTypography.labelSmall.copyWith(color: context.colors.textFaint)),
        const SizedBox(height: AppSpacing.sm),
        const SizedBox(
          width: 500,
          child: AppFormErrorBanner('Já existe um aluno com este CPF nesta academia.'),
        ),
      ],
    );
  }
}

class _DialogsShowcase extends StatelessWidget {
  const _DialogsShowcase();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final variant in AppConfirmDialogVariant.values)
          AppButton(
            label: variant.name,
            variant: AppButtonVariant.secondary,
            onPressed: () => AppConfirmDialog.show(
              context,
              variant: variant,
              title: 'Remover aluno',
              description: 'Remover Mariana Ferreira? O cadastro fica inativo e preservado.',
              confirmLabel: 'Remover',
            ),
          ),
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
        const SizedBox(height: AppSpacing.xl),
        Text('AppPagination', style: AppTypography.labelSmall.copyWith(color: colors.textFaint)),
        const SizedBox(height: AppSpacing.sm),
        AppPagination(page: 1, pageSize: 20, total: 128, onPageChanged: (_) {}),
        const SizedBox(height: AppSpacing.sm),
        AppPagination(page: 4, pageSize: 20, total: 128, onPageChanged: (_) {}),
        const SizedBox(height: AppSpacing.sm),
        AppPagination(page: 1, pageSize: 20, total: 12, onPageChanged: (_) {}),
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
