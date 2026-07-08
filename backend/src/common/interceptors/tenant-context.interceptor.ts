import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { Observable } from 'rxjs';
import { TenantContextService } from '../context/tenant-context.service';

/// Popula o TenantContext (AsyncLocalStorage) para toda a execução do
/// handler — controllers e services em qualquer profundidade de chamada
/// leem `academiaId`/`userId`/`role` sem recebê-los como parâmetro.
///
/// A subscription do Observable retornado por `next.handle()` precisa
/// acontecer *dentro* de `tenantContext.run()` — é a subscription que
/// dispara a execução real do handler (Observables são lazy). Só envolver a
/// chamada de `next.handle()` não bastaria, porque ela apenas retorna o
/// Observable sem executar nada ainda.
@Injectable()
export class TenantContextInterceptor implements NestInterceptor {
  constructor(private readonly tenantContext: TenantContextService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user) {
      return next.handle();
    }

    return new Observable((subscriber) => {
      this.tenantContext.run(user, () => {
        next.handle().subscribe(subscriber);
      });
    });
  }
}
