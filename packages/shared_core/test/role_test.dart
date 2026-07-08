import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

void main() {
  group('Role', () {
    test('fromJson/toJson faz round-trip com o valor do backend', () {
      for (final role in Role.values) {
        expect(Role.fromJson(role.toJson()), role);
      }
    });

    test('fromJson lança para valor desconhecido', () {
      expect(() => Role.fromJson('INEXISTENTE'), throwsArgumentError);
    });
  });
}
