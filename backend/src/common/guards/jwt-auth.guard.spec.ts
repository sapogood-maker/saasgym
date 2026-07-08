import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from './jwt-auth.guard';

function createContext(request: Record<string, unknown>): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => request }),
    getHandler: () => ({}),
    getClass: () => ({}),
  } as unknown as ExecutionContext;
}

describe('JwtAuthGuard', () => {
  let guard: JwtAuthGuard;
  let reflector: { getAllAndOverride: jest.Mock };
  let jwtService: { verifyAsync: jest.Mock };
  let configService: { get: jest.Mock };

  beforeEach(() => {
    reflector = { getAllAndOverride: jest.fn().mockReturnValue(false) };
    jwtService = { verifyAsync: jest.fn() };
    configService = { get: jest.fn().mockReturnValue('test-secret') };

    guard = new JwtAuthGuard(
      reflector as unknown as Reflector,
      jwtService as unknown as JwtService,
      configService as unknown as ConfigService,
    );
  });

  it('libera rotas marcadas com @Public() sem checar token', async () => {
    reflector.getAllAndOverride.mockReturnValue(true);
    const context = createContext({ headers: {} });

    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(jwtService.verifyAsync).not.toHaveBeenCalled();
  });

  it('rejeita quando não há header Authorization', async () => {
    const context = createContext({ headers: {} });

    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejeita token inválido/expirado', async () => {
    jwtService.verifyAsync.mockRejectedValue(new Error('expirado'));
    const context = createContext({ headers: { authorization: 'Bearer token-invalido' } });

    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('popula request.user a partir de um token válido', async () => {
    jwtService.verifyAsync.mockResolvedValue({
      sub: 'user-1',
      academiaId: 'academia-1',
      role: Role.ACADEMIA_ADMIN,
    });
    const request: Record<string, unknown> = { headers: { authorization: 'Bearer token-valido' } };
    const context = createContext(request);

    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(request.user).toEqual({
      userId: 'user-1',
      academiaId: 'academia-1',
      role: Role.ACADEMIA_ADMIN,
    });
  });

  it('academiaId null (SYSTEM_ADMIN) é propagado para request.user', async () => {
    jwtService.verifyAsync.mockResolvedValue({
      sub: 'sys-1',
      academiaId: null,
      role: Role.SYSTEM_ADMIN,
    });
    const request: Record<string, unknown> = { headers: { authorization: 'Bearer token-valido' } };
    const context = createContext(request);

    await guard.canActivate(context);

    expect((request.user as { academiaId: string | null }).academiaId).toBeNull();
  });
});
