import { Controller, Get, INestApplication } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { Test } from '@nestjs/testing';
import request from 'supertest';

/// Prova, via HTTP real, que o ThrottlerGuard de fato bloqueia com 429 após
/// o limite — com um limite baixo e fixo, isolado do app real (que usa um
/// limite bem mais alto em NODE_ENV=test para não travar os próprios
/// testes e2e de auth). Ver AuthController para o limite real de /auth/login.
@Controller('test')
class ThrottledTestController {
  @Get('limited')
  limited() {
    return { ok: true };
  }
}

describe('ThrottlerGuard (integração via HTTP real)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [ThrottlerModule.forRoot([{ name: 'default', ttl: 60_000, limit: 3 }])],
      controllers: [ThrottledTestController],
      providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
    }).compile();

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('libera até o limite e bloqueia com 429 a partir da próxima', async () => {
    await request(app.getHttpServer()).get('/test/limited').expect(200);
    await request(app.getHttpServer()).get('/test/limited').expect(200);
    await request(app.getHttpServer()).get('/test/limited').expect(200);

    await request(app.getHttpServer()).get('/test/limited').expect(429);
  });
});
