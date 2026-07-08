# API

REST + Swagger. Sem GraphQL/tRPC.

## Convenções

- Prefixo global: `/api` (ex.: `/api/health`, `/api/auth/login`).
- Documentação interativa (Swagger UI): `/api/docs`, gerada a partir dos decorators `@nestjs/swagger` nos controllers/DTOs — não escrever a documentação separadamente do código.
- Autenticação: header `Authorization: Bearer <accessToken>` (ver `docs/03-fluxo-autenticacao.md`).
- Validação de entrada: DTOs com `class-validator`, `ValidationPipe` global com `whitelist: true` e `forbidNonWhitelisted: true` — payloads com campos não declarados no DTO são rejeitados.
- Nomenclatura de rotas: recursos no plural em português (`/alunos`, `/professores`, `/planos`), verbos HTTP padrão (`GET`/`POST`/`PATCH`/`DELETE`).
- Todo endpoint de entidade tenant-scoped opera implicitamente sobre a academia do usuário autenticado (via `@TenantId()`) — a academia nunca é um parâmetro arbitrário vindo do cliente, exceto nos endpoints de `SYSTEM_ADMIN`.

## Organização por módulo

Cada módulo de domínio (`backend/src/modules/<dominio>/`) expõe seu próprio controller e DTOs. Convenções de nomenclatura de arquivo: `<dominio>.controller.ts`, `<dominio>.service.ts`, `dto/create-<dominio>.dto.ts`, `dto/update-<dominio>.dto.ts`.

## Erros

Filtro global de exceções padroniza o formato de erro (implementado junto com o hardening do Sprint 11). Até lá, os erros seguem o formato padrão do NestJS (`{ statusCode, message, error }`).

## Health-check

`GET /api/health` — usado por Docker/Coolify para verificar se a API e a conexão com o PostgreSQL estão saudáveis. Retorna `{ status: "ok", timestamp }`.
