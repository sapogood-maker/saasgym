import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_web/app.dart';

void main() {
  testWidgets('AdminApp renderiza a tela inicial', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AdminApp()));

    expect(find.text('SaaSGym — Painel Administrativo'), findsOneWidget);
  });
}
