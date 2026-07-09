import { Transform } from 'class-transformer';
import { registerDecorator, ValidationOptions } from 'class-validator';

/// Sequências que passam matematicamente no algoritmo de dígito
/// verificador mas nunca são CPFs reais (todos os dígitos iguais).
const SEQUENCIAS_INVALIDAS = new Set(
  Array.from({ length: 10 }, (_, digito) => String(digito).repeat(11)),
);

function calculaDigitoVerificador(digitos: string, pesoInicial: number): number {
  const soma = digitos
    .split('')
    .reduce((acc, digito, index) => acc + Number(digito) * (pesoInicial - index), 0);
  const resto = soma % 11;
  return resto < 2 ? 0 : 11 - resto;
}

/// Algoritmo real de dígito verificador do CPF (módulo 11) — não é só
/// checagem de formato/tamanho. `cpf` deve conter só dígitos (o chamador
/// já removeu pontuação).
export function isValidCPF(cpf: string): boolean {
  if (!/^\d{11}$/.test(cpf) || SEQUENCIAS_INVALIDAS.has(cpf)) {
    return false;
  }

  const primeiroDigito = calculaDigitoVerificador(cpf.slice(0, 9), 10);
  if (primeiroDigito !== Number(cpf[9])) {
    return false;
  }

  const segundoDigito = calculaDigitoVerificador(cpf.slice(0, 10), 11);
  return segundoDigito === Number(cpf[10]);
}

/// Valida o CPF (com ou sem pontuação/traço — a máscara é removida antes
/// de checar o dígito verificador).
export function IsCPF(validationOptions?: ValidationOptions) {
  return function (object: object, propertyName: string) {
    registerDecorator({
      name: 'isCPF',
      target: object.constructor,
      propertyName,
      options: {
        message: 'CPF inválido',
        ...validationOptions,
      },
      validator: {
        validate(value: unknown): boolean {
          return typeof value === 'string' && isValidCPF(value.replace(/\D/g, ''));
        },
      },
    });
  };
}

/// Remove a pontuação do CPF antes de validar/persistir — sem isso, o
/// mesmo CPF com/sem máscara ("111.444.777-35" vs "11144477735") burlaria
/// o `@@unique([academiaId, cpf])` e a pesquisa por CPF (que faz `contains`
/// literal na string armazenada) ficaria sensível à formatação de entrada.
export function NormalizeCPF() {
  return Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.replace(/\D/g, '') : value,
  );
}
