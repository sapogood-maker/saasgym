import { resolve } from 'node:path';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestExpressApplication } from '@nestjs/platform-express';
import { Test, TestingModule } from '@nestjs/testing';
import cookieParser from 'cookie-parser';
import { AppModule } from '../../src/app.module';

/// Replica o bootstrap de src/main.ts para os testes e2e — mesmo prefixo
/// global, mesmo ValidationPipe, mesmo cookie-parser, mesmo static assets
/// de uploads, para que o comportamento testado seja o mesmo da API real.
export async function createTestApp(): Promise<NestExpressApplication> {
  const moduleFixture: TestingModule = await Test.createTestingModule({
    imports: [AppModule],
  }).compile();

  const app = moduleFixture.createNestApplication<NestExpressApplication>();
  const config = app.get(ConfigService);

  app.use(cookieParser());
  app.useStaticAssets(resolve(config.get<string>('UPLOADS_DIR', './uploads')), {
    prefix: '/uploads',
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  app.setGlobalPrefix('api');
  await app.init();

  return app;
}
