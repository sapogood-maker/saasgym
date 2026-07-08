import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:student_web/app.dart';

void main() {
  testWidgets('StudentApp renderiza a tela inicial', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudentApp()));

    expect(find.text('SaaSGym — Portal do Aluno'), findsOneWidget);
  });
}
