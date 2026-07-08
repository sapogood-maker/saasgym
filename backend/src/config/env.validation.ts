import { plainToInstance } from 'class-transformer';
import { IsIn, IsInt, IsString, Max, Min, MinLength, validateSync } from 'class-validator';

enum Environment {
  Development = 'development',
  Production = 'production',
  Test = 'test',
}

class EnvironmentVariables {
  @IsIn([Environment.Development, Environment.Production, Environment.Test])
  NODE_ENV: Environment = Environment.Development;

  @IsInt()
  @Min(1)
  @Max(65535)
  PORT: number = 3000;

  @IsString()
  DATABASE_URL!: string;

  // 32 caracteres é o mínimo razoável para um segredo HMAC — falha rápido no
  // boot em vez de subir com um segredo fraco/placeholder em produção.
  @IsString()
  @MinLength(32, { message: 'JWT_ACCESS_SECRET deve ter pelo menos 32 caracteres' })
  JWT_ACCESS_SECRET!: string;

  @IsString()
  @MinLength(32, { message: 'JWT_REFRESH_SECRET deve ter pelo menos 32 caracteres' })
  JWT_REFRESH_SECRET!: string;

  @IsString()
  JWT_ACCESS_EXPIRATION: string = '15m';

  @IsString()
  JWT_REFRESH_EXPIRATION: string = '7d';

  @IsString()
  CORS_ORIGINS: string = 'http://localhost:5000,http://localhost:5001';
}

export function validateEnv(config: Record<string, unknown>) {
  const validatedConfig = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });

  const errors = validateSync(validatedConfig, { skipMissingProperties: false });

  if (errors.length > 0) {
    throw new Error(`Configuração de ambiente inválida: ${errors.toString()}`);
  }

  return validatedConfig;
}
