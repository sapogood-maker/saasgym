import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

/// Testes de fumaça dos componentes do Design System — garantem que cada
/// um builda sem lançar exceção, sob o tema real (`AppTheme.darkPremium()`,
/// já que todos dependem de `context.colors` via `ThemeExtension`).
Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkPremium(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('AppButton builda em todas as variantes e estados', (tester) async {
    await tester.pumpWidget(
      _harness(
        Wrap(
          children: [
            for (final variant in AppButtonVariant.values)
              AppButton(label: variant.name, onPressed: () {}, variant: variant),
            const AppButton(label: 'Disabled', onPressed: null),
            AppButton(label: 'Loading', onPressed: () {}, loading: true),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('primary'), findsOneWidget);
  });

  testWidgets('AppButton com rótulo longo trunca em vez de estourar o layout', (tester) async {
    // Regressão: Row(mainAxisSize: min) sem Flexible/ellipsis explodia
    // (RenderFlex overflow) quando o botão ficava num container estreito
    // (ex.: dentro de um EmptyState de 320px) com um rótulo longo.
    await tester.pumpWidget(
      _harness(
        SizedBox(
          width: 140,
          child: AppButton(label: 'Cadastrar primeiro aluno', onPressed: () {}),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('AppButton em loading mantém a cor cheia (não fica com opacidade de disabled)', (tester) async {
    // Regressão: loading reaproveita onPressed=null para bloquear duplo
    // clique, o que também acionava o dimming de "disabled" — loading deve
    // parecer ativo/ocupado, não desabilitado.
    final key = GlobalKey();
    await tester.pumpWidget(
      _harness(AppButton(key: key, label: 'Salvando', onPressed: () {}, loading: true)),
    );

    final material = tester.widget<Material>(
      find.descendant(of: find.byKey(key), matching: find.byType(Material)).first,
    );
    final colors = AppColorScheme.darkPremium();
    expect(material.color, colors.primary);
  });

  testWidgets('AppCard builda com título, ações, rodapé e em loading', (tester) async {
    await tester.pumpWidget(
      _harness(
        Column(
          children: [
            AppCard(
              title: 'Título',
              subtitle: 'Subtítulo',
              actions: const [AppBadge('4')],
              footer: const Text('Rodapé'),
              child: const Text('Conteúdo'),
            ),
            const AppCard(title: 'Carregando', loading: true),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Título'), findsOneWidget);
    expect(find.text('Conteúdo'), findsOneWidget);
    expect(find.text('Rodapé'), findsOneWidget);
  });

  testWidgets('AppBadge builda em todos os tons', (tester) async {
    await tester.pumpWidget(
      _harness(
        Wrap(
          children: [for (final tone in AppBadgeTone.values) AppBadge(tone.name, tone: tone)],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('EmptyState builda nas duas variantes', (tester) async {
    await tester.pumpWidget(
      _harness(
        Column(
          children: [
            EmptyState(
              icon: AppIcons.students,
              title: 'Nenhum aluno cadastrado',
              actionLabel: 'Cadastrar primeiro aluno',
              onAction: () {},
            ),
            const EmptyState.comingSoon(
              icon: AppIcons.finance,
              title: 'Financeiro',
              sprintTag: 'SPRINT 6',
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Nenhum aluno cadastrado'), findsOneWidget);
    expect(find.text('SPRINT 6'), findsOneWidget);
  });

  testWidgets('LoadingSkeleton builda em retângulo e círculo', (tester) async {
    await tester.pumpWidget(
      _harness(
        const Row(
          children: [
            LoadingSkeleton(),
            LoadingSkeleton(shape: AppSkeletonShape.circle, width: 40, height: 40),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('MetricCard builda com e sem destaque/delta', (tester) async {
    await tester.pumpWidget(
      _harness(
        Column(
          children: [
            MetricCard(label: 'Alunos ativos', value: '128', icon: AppIcons.students, highlight: true, deltaLabel: '+6 este mês', trend: AppMetricTrend.up),
            const MetricCard(label: 'Inadimplentes', value: '—'),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('128'), findsOneWidget);
  });

  testWidgets('MetricCard fica lado a lado num Wrap (não ocupa a linha inteira)', (tester) async {
    // Regressão: sem largura própria, o Row interno (spaceBetween) expandia
    // pra ocupar toda a largura oferecida pelo Wrap, empurrando cada card
    // pra sua própria linha em vez de ficarem lado a lado.
    await tester.pumpWidget(
      _harness(
        const Wrap(
          children: [
            MetricCard(label: 'Alunos ativos', value: '128'),
            MetricCard(label: 'Professores', value: '9'),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final primeiro = tester.getTopLeft(find.text('Alunos ativos'));
    final segundo = tester.getTopLeft(find.text('Professores'));
    expect(primeiro.dy, equals(segundo.dy), reason: 'os dois cards deveriam estar na mesma linha');
  });

  testWidgets('AppBreadcrumb builda com 1 e com múltiplos segmentos', (tester) async {
    await tester.pumpWidget(
      _harness(
        const Column(
          children: [
            AppBreadcrumb(['Dashboard']),
            AppBreadcrumb(['Alunos', 'Mariana Ferreira']),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Mariana Ferreira'), findsOneWidget);
  });

  testWidgets('AppHeader builda com breadcrumb e botão de menu', (tester) async {
    await tester.pumpWidget(
      _harness(
        AppHeader(breadcrumb: const AppBreadcrumb(['Dashboard']), onMenuTap: () {}),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('AppHeader não estoura em largura de celular (busca vira ícone)', (tester) async {
    // Regressão: busca de 260px fixos não cabia ao lado de menu +
    // breadcrumb + notificações numa tela de 390px de largura.
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        AppHeader(breadcrumb: const AppBreadcrumb(['Dashboard']), onMenuTap: () {}),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('AppSidebar builda com itens habilitados, desabilitados e seções', (tester) async {
    await tester.pumpWidget(
      _harness(
        SizedBox(
          height: 700,
          child: AppSidebar(
            academiaNome: 'Academia Demo',
            planoNome: 'Trial',
            destinations: const [
              AppSidebarDestination(label: 'Dashboard', icon: AppIcons.dashboard, path: '/', section: 'Operação'),
              AppSidebarDestination(label: 'Alunos', icon: AppIcons.students, path: '/alunos', section: 'Operação'),
              AppSidebarDestination(label: 'Financeiro', icon: AppIcons.finance, path: '/financeiro', section: 'Operação', enabled: false),
              AppSidebarDestination(label: 'Meu perfil', icon: AppIcons.profile, path: '/perfil', section: 'Conta'),
            ],
            currentPath: '/',
            onDestinationSelected: (_) {},
            userNome: 'Ana Admin',
            userCargo: 'Administrador',
            onProfileTap: () {},
            onLogout: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Academia Demo'), findsOneWidget);
    expect(find.text('Alunos'), findsOneWidget);
    expect(find.text('em breve'), findsOneWidget);
  });

  testWidgets('AppListTile builda com e sem trailing/onTap', (tester) async {
    await tester.pumpWidget(
      _harness(
        Column(
          children: [
            const AppListTile(title: 'Mariana Ferreira', subtitle: 'Plano Trimestral', leadingText: 'MF'),
            AppListTile(
              title: 'Rodrigo Castro',
              leadingText: 'RC',
              trailing: const AppBadge('12/jul'),
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Mariana Ferreira'), findsOneWidget);
    expect(find.text('12/jul'), findsOneWidget);
  });
}
