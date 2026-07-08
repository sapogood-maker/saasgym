import { Controller, Get, INestApplication, UseGuards } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { APP_GUARD, Reflector } from '@nestjs/core';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import { Role } from '@prisma/client';
import request from 'supertest';
import { AcademiaGuard } from './academia.guard';
import { JwtAuthGuard } from './jwt-auth.guard';
import { RolesGuard } from './roles.guard';
import { CurrentAcademia } from '../decorators/current-academia.decorator';
import { CurrentUser } from '../decorators/current-user.decorator';
import { Public } from '../decorators/public.decorator';
import { Roles } from '../decorators/roles.decorator';
import { AuthenticatedUser } from '../types/authenticated-user.interface';

const TEST_SECRET = 'integration-test-secret';

/// Controller só usado por este teste — nunca registrado no app real.
/// Existe para provar, via HTTP de verdade, que JwtAuthGuard + RolesGuard +
/// AcademiaGuard + os decorators funcionam juntos (nenhum endpoint do
/// próprio Sprint 1 precisa dessas combinações — ver docs/10-auth.md).
@Controller('test')
@UseGuards(JwtAuthGuard, RolesGuard)
class GuardedTestController {
  @Public()
  @Get('public')
  publicRoute() {
    return { ok: true };
  }

  @Get('protected')
  protectedRoute(@CurrentUser() user: AuthenticatedUser) {
    return user;
  }

  @Roles(Role.SYSTEM_ADMIN)
  @Get('admin-only')
  adminOnly() {
    return { ok: true };
  }

  @UseGuards(AcademiaGuard)
  @Get('academia-only')
  academiaOnly(@CurrentAcademia() academiaId: string | null) {
    return { academiaId };
  }
}

describe('Guards (integração via HTTP real)', () => {
  let app: INestApplication;
  let jwtService: JwtService;

  function signToken(payload: { sub: string; academiaId: string | null; role: Role }) {
    return jwtService.sign(payload, { secret: TEST_SECRET, expiresIn: '15m' });
  }

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [JwtModule.register({})],
      controllers: [GuardedTestController],
      providers: [
        { provide: ConfigService, useValue: { get: () => TEST_SECRET } },
        { provide: APP_GUARD, useClass: JwtAuthGuard },
        Reflector,
      ],
    }).compile();

    app = moduleRef.createNestApplication();
    await app.init();
    jwtService = moduleRef.get(JwtService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /test/public funciona sem token (@Public)', async () => {
    await request(app.getHttpServer()).get('/test/public').expect(200, { ok: true });
  });

  it('GET /test/protected sem token -> 401', async () => {
    await request(app.getHttpServer()).get('/test/protected').expect(401);
  });

  it('GET /test/protected com token válido -> 200 e retorna o usuário', async () => {
    const token = signToken({ sub: 'user-1', academiaId: 'academia-1', role: Role.PROFESSOR });

    const response = await request(app.getHttpServer())
      .get('/test/protected')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(response.body).toEqual({
      userId: 'user-1',
      academiaId: 'academia-1',
      role: Role.PROFESSOR,
    });
  });

  it('GET /test/admin-only com role errado -> 403', async () => {
    const token = signToken({ sub: 'user-1', academiaId: 'academia-1', role: Role.PROFESSOR });

    await request(app.getHttpServer())
      .get('/test/admin-only')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  it('GET /test/admin-only com SYSTEM_ADMIN -> 200', async () => {
    const token = signToken({ sub: 'sys-1', academiaId: null, role: Role.SYSTEM_ADMIN });

    await request(app.getHttpServer())
      .get('/test/admin-only')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
  });

  it('GET /test/academia-only com SYSTEM_ADMIN (academiaId null) -> 403', async () => {
    const token = signToken({ sub: 'sys-1', academiaId: null, role: Role.SYSTEM_ADMIN });

    await request(app.getHttpServer())
      .get('/test/academia-only')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  it('GET /test/academia-only com usuário de academia -> 200', async () => {
    const token = signToken({ sub: 'user-1', academiaId: 'academia-1', role: Role.ACADEMIA_ADMIN });

    const response = await request(app.getHttpServer())
      .get('/test/academia-only')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(response.body).toEqual({ academiaId: 'academia-1' });
  });
});
