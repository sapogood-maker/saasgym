import {
  CallHandler,
  Controller,
  ExecutionContext,
  Get,
  INestApplication,
  UseInterceptors,
} from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import { Role } from '@prisma/client';
import { Observable } from 'rxjs';
import request from 'supertest';
import { TenantContextInterceptor } from './tenant-context.interceptor';
import { TenantContextService } from '../context/tenant-context.service';

/// Simula um middleware/guard que já rodou antes e populou request.user —
/// este teste foca só no interceptor, não no JwtAuthGuard.
function fakeAuthMiddleware(req: { user?: unknown }, _res: unknown, next: () => void) {
  req.user = { userId: 'user-1', academiaId: 'academia-1', role: Role.ACADEMIA_ADMIN };
  next();
}

@Controller('test')
@UseInterceptors(TenantContextInterceptor)
class ContextTestController {
  constructor(private readonly tenantContext: TenantContextService) {}

  @Get('sync')
  readSync() {
    return { academiaId: this.tenantContext.getAcademiaId() };
  }

  @Get('after-await')
  async readAfterAwait() {
    // Simula uma consulta ao banco (ou qualquer I/O) antes de ler o
    // contexto — é exatamente o cenário em que enterWith() falhava.
    await new Promise((resolve) => setTimeout(resolve, 5));
    return { academiaId: this.tenantContext.getAcademiaId() };
  }
}

describe('TenantContextInterceptor (integração via HTTP real)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [ContextTestController],
      providers: [
        TenantContextService,
        { provide: APP_INTERCEPTOR, useClass: TenantContextInterceptor },
      ],
    }).compile();

    app = moduleRef.createNestApplication();
    app.use(fakeAuthMiddleware);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('contexto disponível de forma síncrona no handler', async () => {
    const response = await request(app.getHttpServer()).get('/test/sync').expect(200);

    expect(response.body).toEqual({ academiaId: 'academia-1' });
  });

  it('contexto continua disponível depois de um await interno no handler', async () => {
    const response = await request(app.getHttpServer()).get('/test/after-await').expect(200);

    expect(response.body).toEqual({ academiaId: 'academia-1' });
  });

  it('duas requisições concorrentes nunca vazam academiaId entre si', async () => {
    const [a, b] = await Promise.all([
      request(app.getHttpServer()).get('/test/after-await'),
      request(app.getHttpServer()).get('/test/after-await'),
    ]);

    expect(a.body).toEqual({ academiaId: 'academia-1' });
    expect(b.body).toEqual({ academiaId: 'academia-1' });
  });

  it('propaga o unsubscribe: cancelar a requisição também cancela o handler interno', () => {
    let innerUnsubscribed = false;

    const fakeCallHandler: CallHandler = {
      handle: () =>
        new Observable(() => {
          return () => {
            innerUnsubscribed = true;
          };
        }),
    };

    const fakeContext = {
      switchToHttp: () => ({
        getRequest: () => ({
          user: { userId: 'u', academiaId: 'academia-1', role: Role.ACADEMIA_ADMIN },
        }),
      }),
    } as unknown as ExecutionContext;

    const interceptor = new TenantContextInterceptor(new TenantContextService());
    const subscription = interceptor.intercept(fakeContext, fakeCallHandler).subscribe();

    expect(innerUnsubscribed).toBe(false);
    subscription.unsubscribe();
    expect(innerUnsubscribed).toBe(true);
  });
});
