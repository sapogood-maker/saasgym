# Multi-Tenant

Implementado no Sprint 1: o mecanismo de isolamento por `academiaId`. As entidades de negócio que vão de fato usar isso (`Aluno`, `Professor`, `Plano`...) chegam a partir do Sprint 2 — este documento descreve a infraestrutura que elas vão herdar automaticamente.

## Regra de ouro

`academiaId` **nunca** vem do frontend. Ele só existe em dois lugares: dentro do JWT (`payload.academiaId`, calculado no login a partir do usuário autenticado) e, a partir daí, no `TenantContext` do request. Nenhum service deve aceitar `academiaId` como parâmetro de entrada vindo de um DTO/query/body.

## TenantContext

`backend/src/common/context/tenant-context.service.ts` — serviço singleton (não `Scope.REQUEST`) baseado em `AsyncLocalStorage`, expõe `getUserId()` / `getAcademiaId()` / `getRole()` para qualquer service, em qualquer profundidade de chamada, sem precisar receber esses valores como parâmetro.

### Por que um Interceptor, e não o Guard, popula o contexto

A primeira versão (durante o planejamento) populava o `TenantContext` dentro do próprio `JwtAuthGuard`, via `AsyncLocalStorage.enterWith()`, logo após verificar o token. Um teste dedicado (`tenant-context.service.spec.ts`) provou que isso **não funciona de forma confiável**: `enterWith()` chamado depois de um `await` interno (a verificação assíncrona do JWT) não propaga o valor de volta para quem chamou o guard — comportamento documentado do Node, não um bug do NestJS.

A correção: `TenantContextInterceptor` (`backend/src/common/interceptors/tenant-context.interceptor.ts`), que roda depois dos guards (ordem garantida pelo NestJS: guards → interceptors → handler) e envolve a **subscription** do `Observable` retornado pelo handler dentro de `tenantContext.run()`:

```ts
return new Observable((subscriber) => {
  this.tenantContext.run(user, () => {
    next.handle().subscribe(subscriber);
  });
});
```

Isso é necessário porque `next.handle()` só retorna o `Observable` — a execução real do handler só acontece quando alguém assina (`.subscribe()`). Envolver só a chamada de `next.handle()` (sem a subscription) não bastaria. Coberto por `tenant-context.interceptor.spec.ts`, incluindo um cenário de duas requisições concorrentes provando que o contexto de uma nunca vaza para a outra.

## Extensão do Prisma (`PrismaService.forTenant()`)

`backend/src/common/prisma/prisma-tenant.extension.ts` — uma Prisma Client Extension que injeta automaticamente `where: { academiaId }` (lido do `TenantContext`) em toda operação de leitura/escrita sobre models tenant-scoped, e `academiaId` automaticamente em `create`/`createMany`.

```ts
// Em qualquer service de negócio (Sprint 2+):
this.prisma.forTenant().aluno.findMany();
// nunca precisa (nem deve) escrever { where: { academiaId } } manualmente
```

Comportamento por perfil:
- **Usuário de uma academia** (`academiaId` presente): toda query fica automaticamente restrita àquela academia, mesmo que o código do service peça outra coisa explicitamente — é a defesa de última linha contra um bug em um service vazar dados entre academias.
- **`SYSTEM_ADMIN`** (`academiaId` null): não é filtrado — precisa enxergar todas as academias para telas de gestão de tenants.
- **Fora de um request autenticado** (seed, scripts): não é filtrado — não há tenant algum para aplicar.

`this.prisma` (sem `.forTenant()`) continua sem filtro nenhum — uso **intencional** para os poucos fluxos genuinamente cross-tenant: login por e-mail (que precisa achar o usuário antes de saber a qual academia ele pertence), seed, e futuros endpoints de gestão de academias pelo `SYSTEM_ADMIN`.

Hoje só `User` está na lista de models tenant-scoped (`TENANT_SCOPED_MODELS` no arquivo da extensão). Cada nova entidade de negócio com `academiaId` (Sprint 2+) entra nessa lista — nenhuma mudança é necessária nos services que já usam `forTenant()`.

A instância retornada por `forTenant()` é construída uma única vez por `PrismaService` e cacheada — não a cada chamada. É seguro: o filtro é resolvido lendo o `TenantContext` dentro do `$allOperations` da extensão, em tempo de query, não em tempo de construção do client.

`upsert` tem forma própria (`where` + `create` + `update` juntos) e não é coberto pelos branches de `where`/`create` genéricos — tem tratamento dedicado na extensão. Sem ele, o branch de update do `upsert` acharia (e sobrescreveria) um registro de outra academia pelo id, ignorando o isolamento por completo — bug real encontrado e corrigido durante a revisão pré-`v0.2.0` (ver `SPRINT1_REPORT.md`).

Testado em `test/prisma-tenant-extension.e2e-spec.ts`: sem contexto não filtra, `SYSTEM_ADMIN` vê tudo, uma academia nunca vê dados de outra mesmo pedindo explicitamente, `create`/`createMany` injetam `academiaId` sozinhos, `count()` respeita o isolamento, `findUnique`/`update`/`delete`/`upsert` por id nunca alcançam (nem quebram tentando alcançar) um registro de outra academia.

## Guards de tenant/perfil

- **`AcademiaGuard`** — exige que o usuário tenha `academiaId` (bloqueia `SYSTEM_ADMIN` em rotas de negócio).
- **`SystemAdminGuard`** — exige `role === SYSTEM_ADMIN`.
- **`RolesGuard`** + `@Roles(...)` — restringe por perfil.

Nenhum endpoint do próprio Sprint 1 usa `AcademiaGuard`/`RolesGuard` de verdade (`/auth/me` funciona para todo mundo, incluindo `SYSTEM_ADMIN`, então não pode usar `AcademiaGuard`) — os três guards são testados via unit tests + um controller de teste isolado (`guards.integration.spec.ts`), nunca registrado no app real. O uso em produção começa no Sprint 2, quando existir o primeiro endpoint restrito por role/tenant de verdade (ex.: só `ACADEMIA_ADMIN` pode cadastrar `Aluno`).
