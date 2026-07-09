# API

REST + Swagger. Sem GraphQL/tRPC.

## Convenções

- Prefixo global: `/api` (ex.: `/api/health`, `/api/auth/login`).
- Documentação interativa (Swagger UI): `/api/docs`, gerada a partir dos decorators `@nestjs/swagger` nos controllers/DTOs — não escrever a documentação separadamente do código.
- Autenticação: header `Authorization: Bearer <accessToken>` (ver `docs/10-auth.md`). Toda rota exige token por padrão — endpoints públicos usam `@Public()` explicitamente (login, refresh, health-check).
- Rate limiting: 60 req/min global, 5 req/min em `/auth/login` (ver `docs/11-security.md`).
- Validação de entrada: DTOs com `class-validator`, `ValidationPipe` global com `whitelist: true` e `forbidNonWhitelisted: true` — payloads com campos não declarados no DTO são rejeitados.
- Nomenclatura de rotas: recursos no plural em português (`/alunos`, `/professores`, `/planos`), verbos HTTP padrão (`GET`/`POST`/`PATCH`/`DELETE`).
- Todo endpoint de entidade tenant-scoped opera implicitamente sobre a academia do usuário autenticado (via `@CurrentAcademia()`, lido do JWT) — a academia nunca é um parâmetro arbitrário vindo do cliente, exceto nos endpoints de `SYSTEM_ADMIN`. Ver `docs/12-multi-tenant.md`.

## Organização por módulo

Cada módulo de domínio (`backend/src/modules/<dominio>/`) expõe seu próprio controller e DTOs. Convenções de nomenclatura de arquivo: `<dominio>.controller.ts`, `<dominio>.service.ts`, `dto/create-<dominio>.dto.ts`, `dto/update-<dominio>.dto.ts`.

## Erros

`AllExceptionsFilter` (global, Sprint 1) padroniza todo erro nesse formato — stack trace nunca vai para a resposta, em nenhum ambiente:

```json
{ "statusCode": 401, "message": "Credenciais inválidas", "error": "UnauthorizedException", "timestamp": "...", "path": "/api/auth/login" }
```

## Health-check

`GET /api/health` — público (`@Public()`), usado por Docker/Coolify para verificar se a API e a conexão com o PostgreSQL estão saudáveis. Retorna `{ status: "ok", timestamp }`.

## Autenticação

Ver `docs/10-auth.md` para os endpoints (`/auth/login`, `/auth/refresh`, `/auth/logout`, `/auth/me`, `/auth/password`) e o fluxo completo.

## Administração do SaaS

Endpoints em `/admin/*` — 100% restritos a `SYSTEM_ADMIN` (`SystemAdminGuard`), nunca acessíveis a usuários de academia. Ver `docs/13-admin-saas.md` para o módulo completo (academias, planos SaaS, dashboard).

## Alunos, Professores, Dashboard da Academia e Perfil

Endpoints `/alunos`, `/professores`, `/dashboard` (`AcademiaGuard` + `RolesGuard`, distinto de `/admin/dashboard`) e `/users/me` (sem `AcademiaGuard` — funciona também para `SYSTEM_ADMIN`, mesmo padrão de `/auth/me`). Primeiros endpoints de negócio acessíveis a usuários de academia. Ver `docs/14-alunos-professores.md` para o módulo completo.
