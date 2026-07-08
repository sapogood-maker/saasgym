import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Role } from '@prisma/client';
import { SystemAdminGuard } from './system-admin.guard';

function createContext(request: Record<string, unknown>): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
}

describe('SystemAdminGuard', () => {
  const guard = new SystemAdminGuard();

  it('libera SYSTEM_ADMIN', () => {
    const context = createContext({ user: { role: Role.SYSTEM_ADMIN } });

    expect(guard.canActivate(context)).toBe(true);
  });

  it('bloqueia qualquer outro role', () => {
    const context = createContext({ user: { role: Role.ACADEMIA_ADMIN } });

    expect(() => guard.canActivate(context)).toThrow(ForbiddenException);
  });

  it('bloqueia quando não há usuário autenticado', () => {
    const context = createContext({});

    expect(() => guard.canActivate(context)).toThrow(ForbiddenException);
  });
});
