import { Injectable } from '@nestjs/common';
import { AsyncLocalStorage } from 'node:async_hooks';
import { Role } from '@prisma/client';
import { AuthenticatedUser } from '../types/authenticated-user.interface';

/// Contexto do usuário autenticado, acessível de qualquer service em
/// qualquer profundidade de chamada, sem precisar de Scope.REQUEST em
/// cascata. Populado pelo TenantContextInterceptor (ver
/// tenant-context.interceptor.ts), nunca a partir de dado vindo do
/// frontend.
///
/// Só expõe `run()`, não um `set()`/`enterWith()` solto: um
/// `AsyncLocalStorage.enterWith()` chamado depois de um `await` dentro de
/// uma função `async` não propaga o valor de volta para quem a chamou —
/// era exatamente o design original do JwtAuthGuard, e um teste provou que
/// não funciona (ver docs/12-multi-tenant.md). Não reexpor essa porta.
@Injectable()
export class TenantContextService {
  private readonly storage = new AsyncLocalStorage<AuthenticatedUser>();

  run<T>(user: AuthenticatedUser, callback: () => T): T {
    return this.storage.run(user, callback);
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
