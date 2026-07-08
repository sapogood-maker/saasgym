import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Role } from '@prisma/client';
import { AcademiaGuard } from './academia.guard';

function createContext(request: Record<string, unknown>): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
}

describe('AcademiaGuard', () => {
  const guard = new AcademiaGuard();

  it('libera usuário com academiaId', () => {
    const context = createContext({
      user: { academiaId: 'academia-1', role: Role.ACADEMIA_ADMIN },
    });

    expect(guard.canActivate(context)).toBe(true);
  });

  it('bloqueia SYSTEM_ADMIN (academiaId null)', () => {
    const context = createContext({ user: { academiaId: null, role: Role.SYSTEM_ADMIN } });

    expect(() => guard.canActivate(context)).toThrow(ForbiddenException);
  });

  it('bloqueia quando não há usuário autenticado', () => {
    const context = createContext({});

    expect(() => guard.canActivate(context)).toThrow(ForbiddenException);
  });
});
