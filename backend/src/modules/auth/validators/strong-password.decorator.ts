import { registerDecorator, ValidationOptions } from 'class-validator';

const STRONG_PASSWORD_REGEX = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;

/// Política mínima de senha: 8+ caracteres, com ao menos uma letra
/// maiúscula, uma minúscula e um número.
export function IsStrongPassword(validationOptions?: ValidationOptions) {
  return function (object: object, propertyName: string) {
    registerDecorator({
      name: 'isStrongPassword',
      target: object.constructor,
      propertyName,
      options: {
        message:
          'A senha deve ter pelo menos 8 caracteres, incluindo letra maiúscula, minúscula e número',
        ...validationOptions,
      },
      validator: {
        validate(value: unknown): boolean {
          return typeof value === 'string' && STRONG_PASSWORD_REGEX.test(value);
        },
      },
    });
  };
}
