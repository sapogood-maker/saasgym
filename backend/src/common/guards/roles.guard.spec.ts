import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { RolesGuard } from './roles.guard';

function createContext(request: Record<string, unknown>): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => request }),
    getHandler: () => ({}),
    getClass: () => ({}),
  } as unknown as ExecutionContext;
}

describe('RolesGuard', () => {
  let reflector: { getAllAndOverride: jest.Mock };
  let guard: RolesGuard;

  beforeEach(() => {
    reflector = { getAllAndOverride: jest.fn() };
    guard = new RolesGuard(reflector as unknown as Reflector);
  });

  it('libera quando a rota não usa @Roles()', () => {
    reflector.getAllAndOverride.mockReturnValue(undefined);
    const context = createContext({ user: { role: Role.PROFESSOR } });

    expect(guard.canActivate(context)).toBe(true);
  });

  it('libera quando o role do usuário está na lista permitida', () => {
    reflector.getAllAndOverride.mockReturnValue([Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA]);
    const context = createContext({ user: { role: Role.ACADEMIA_ADMIN } });

    expect(guard.canActivate(context)).toBe(true);
  });

  it('bloqueia quando o role do usuário não está na lista permitida', () => {
    reflector.getAllAndOverride.mockReturnValue([Role.SYSTEM_ADMIN]);
    const context = createContext({ user: { role: Role.ALUNO } });

    expect(() => guard.canActivate(context)).toThrow(ForbiddenException);
  });

  it('bloqueia quando não há usuário autenticado', () => {
    reflector.getAllAndOverride.mockReturnValue([Role.SYSTEM_ADMIN]);
    const context = createContext({});

    expect(() => guard.canActivate(context)).toThrow(ForbiddenException);
  });
});
