/// Sequências que passam matematicamente no algoritmo de dígito
/// verificador mas nunca são CPFs reais (todos os dígitos iguais).
final _sequenciasInvalidas = {for (final digito in List.generate(10, (i) => i)) digito.toString() * 11};

int _calculaDigitoVerificador(String digitos, int pesoInicial) {
  var soma = 0;
  for (var i = 0; i < digitos.length; i++) {
    soma += int.parse(digitos[i]) * (pesoInicial - i);
  }
  final resto = soma % 11;
  return resto < 2 ? 0 : 11 - resto;
}

/// Algoritmo real de dígito verificador do CPF (módulo 11) — mesma
/// implementação de `backend/src/common/validators/is-cpf.decorator.ts`,
/// portada aqui pra dar feedback imediato no formulário (o backend
/// continua sendo a validação que decide de verdade). Aceita com ou sem
/// pontuação/traço.
bool isValidCpf(String cpf) {
  final digitos = cpf.replaceAll(RegExp(r'\D'), '');
  if (!RegExp(r'^\d{11}$').hasMatch(digitos) || _sequenciasInvalidas.contains(digitos)) {
    return false;
  }

  final primeiroDigito = _calculaDigitoVerificador(digitos.substring(0, 9), 10);
  if (primeiroDigito != int.parse(digitos[9])) {
    return false;
  }

  final segundoDigito = _calculaDigitoVerificador(digitos.substring(0, 10), 11);
  return segundoDigito == int.parse(digitos[10]);
}
