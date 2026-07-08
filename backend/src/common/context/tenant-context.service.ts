import { Injectable } from '@nestjs/common';
import { AsyncLocalStorage } from 'node:async_hooks';
import { Role } from '@prisma/client';
import { AuthenticatedUser } from '../types/authenticated-user.interface';

/// Contexto do usuário autenticado, acessível de qualquer service em
/// qualquer profundidade de chamada, sem precisar de Scope.REQUEST em
/// cascata. Populado pelo JwtAuthGuard via `set()` logo após verificar o
/// access token — nunca a partir de dado vindo do frontend.
@Injectable()
export class TenantContextService {
  private readonly storage = new AsyncLocalStorage<AuthenticatedUser>();

  run<T>(user: AuthenticatedUser, callback: () => T): T {
    return this.storage.run(user, callback);
  }

  set(user: AuthenticatedUser): void {
    this.storage.enterWith(user);
  }

  getUser(): AuthenticatedUser | undefined {
    return this.storage.getStore();
  }

  getUserId(): string | undefined {
    return this.getUser()?.userId;
  }

  getAcademiaId(): string | null | undefined {
    return this.getUser()?.academiaId;
  }

  getRole(): Role | undefined {
    return this.getUser()?.role;
  }
}
