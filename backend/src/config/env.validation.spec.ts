import 'reflect-metadata';
import { validateEnv } from './env.validation';

describe('validateEnv', () => {
  const validConfig = {
    DATABASE_URL: 'postgresql://user:pass@localhost:5432/db',
    JWT_ACCESS_SECRET: 'a'.repeat(32),
    JWT_REFRESH_SECRET: 'b'.repeat(32),
  };

  it('aceita uma configuração válida e aplica os defaults', () => {
    const result = validateEnv(validConfig);

    expect(result.NODE_ENV).toBe('development');
    expect(result.PORT).toBe(3000);
    expect(result.JWT_ACCESS_EXPIRATION).toBe('15m');
  });

  it('rejeita JWT_ACCESS_SECRET com menos de 32 caracteres', () => {
    expect(() => validateEnv({ ...validConfig, JWT_ACCESS_SECRET: 'curto-demais' })).toThrow(
      /32 caracteres/,
    );
  });

  it('rejeita JWT_REFRESH_SECRET com menos de 32 caracteres', () => {
    expect(() => validateEnv({ ...validConfig, JWT_REFRESH_SECRET: 'curto-demais' })).toThrow(
      /32 caracteres/,
    );
  });

  it('rejeita NODE_ENV fora do enum permitido', () => {
    expect(() => validateEnv({ ...validConfig, NODE_ENV: 'staging' })).toThrow();
  });

  it('rejeita PORT fora do intervalo válido', () => {
    expect(() => validateEnv({ ...validConfig, PORT: 70000 })).toThrow();
  });

  it('exige DATABASE_URL', () => {
    const rest: Record<string, unknown> = { ...validConfig };
    delete rest.DATABASE_URL;
    expect(() => validateEnv(rest)).toThrow();
  });
});
