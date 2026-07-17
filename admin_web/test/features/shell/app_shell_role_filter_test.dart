import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

import 'package:admin_web/app.dart';

class _AdapterSemRede implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(requestOptions: options, reason: 'sem rede no teste de widget');
  }

  @override
  void close({bool force = false}) {}
}

/// Dashboard/Mensalidades/Caixa/Painel/Modalidades/Turmas/Calendário/
/// Reposições/Relatórios exigem ACADEMIA_ADMIN/RECEPCIONISTA no backend —
/// PROFESSOR recebe 403 em todos esses hoje (docs/30, achado "Fortemente
/// recomendado: filtrar a sidebar por papel"). Este teste prova que a
/// sidebar não oferece o que o papel não consegue abrir.
void main() {
  Future<ProviderContainer> montarShellComo(WidgetTester tester, Role role) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        dashboardApiProvider.overrideWithValue(
          DashboardApi(Dio()..httpClientAdapter = _AdapterSemRede()),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(authSessionProvider.notifier)
        .setSession(
          accessToken: 'token-fake',
          user: AuthenticatedUser(
            id: 'user-1',
            nome: 'Usuário Teste',
            email: 'teste@example.com',
            role: role,
            academiaId: 'academia-1',
          ),
        );

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const AdminApp()));
    await tester.pumpAndSettle();
    return container;
  }

  // "Dashboard" também aparece fora da sidebar (breadcrumb do header, com
  // o título da rota atual) — os finders abaixo escopam pra dentro do
  // `AppSidebar`, senão um item corretamente ausente do menu ainda seria
  // "encontrado" em outro lugar da tela.
  Finder naSidebar(String texto) => find.descendant(of: find.byType(AppSidebar), matching: find.text(texto));

  testWidgets('PROFESSOR não vê itens de menu que o backend bloqueia pra esse papel', (
    WidgetTester tester,
  ) async {
    await montarShellComo(tester, Role.professor);

    expect(naSidebar('Dashboard'), findsNothing);
    expect(naSidebar('Mensalidades'), findsNothing);
    expect(naSidebar('Caixa'), findsNothing);
    expect(naSidebar('Painel'), findsNothing);
    expect(naSidebar('Modalidades'), findsNothing);
    expect(naSidebar('Turmas'), findsNothing);
    expect(naSidebar('Calendário'), findsNothing);
    expect(naSidebar('Reposições'), findsNothing);
    expect(naSidebar('Relatórios'), findsNothing);

    // Sem restrição de papel no backend — continuam disponíveis.
    expect(naSidebar('Alunos'), findsWidgets);
    expect(naSidebar('Professores'), findsWidgets);
    expect(naSidebar('Planos'), findsWidgets);
    expect(naSidebar('Matrículas'), findsWidgets);
    await tester.scrollUntilVisible(
      naSidebar('Meu perfil'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(naSidebar('Meu perfil'), findsWidgets);
  });

  testWidgets('ACADEMIA_ADMIN continua vendo o menu completo', (WidgetTester tester) async {
    await montarShellComo(tester, Role.academiaAdmin);

    expect(naSidebar('Dashboard'), findsWidgets);
    expect(naSidebar('Mensalidades'), findsWidgets);
    expect(naSidebar('Relatórios'), findsWidgets);
  });

  testWidgets('RECEPCIONISTA continua vendo o menu completo', (WidgetTester tester) async {
    await montarShellComo(tester, Role.recepcionista);

    expect(naSidebar('Dashboard'), findsWidgets);
    expect(naSidebar('Mensalidades'), findsWidgets);
    expect(naSidebar('Relatórios'), findsWidgets);
  });
}
