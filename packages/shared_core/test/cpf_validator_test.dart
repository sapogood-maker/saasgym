import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

void main() {
  group('isValidCpf', () {
    for (final cpf in ['11144477735', '52998224725']) {
      test('aceita um CPF real e válido ($cpf)', () {
        expect(isValidCpf(cpf), isTrue);
      });
    }

    test('aceita CPF com pontuação/traço, desde que o dígito verificador esteja correto', () {
      expect(isValidCpf('111.444.777-35'), isTrue);
    });

    test('rejeita dígito verificador incorreto', () {
      expect(isValidCpf('11144477736'), isFalse);
    });

    for (final cpf in ['00000000000', '11111111111', '99999999999']) {
      test('rejeita sequências de dígitos repetidos, mesmo passando na conta ($cpf)', () {
        expect(isValidCpf(cpf), isFalse);
      });
    }

    test('rejeita tamanho errado', () {
      expect(isValidCpf('123456789'), isFalse);
      expect(isValidCpf('111444777350'), isFalse);
    });

    test('rejeita valor vazio', () {
      expect(isValidCpf(''), isFalse);
    });
  });
}
