# Arquitetura

## Visão geral

O SaaSGym é um **monorepo** com três aplicações e um pacote compartilhado:

| Pasta | O quê | Stack |
|---|---|---|
| `backend/` | API REST | NestJS + Prisma + PostgreSQL |
| `admin_web/` | Painel administrativo | Flutter Web + Riverpod + GoRouter |
| `student_web/` | Portal do aluno | Flutter Web + Riverpod + GoRouter |
| `packages/shared_core/` | Código compartilhado entre os dois Flutter Web | Dart puro/Flutter |

Os dois frontends consomem exatamente a mesma API REST e o mesmo pacote `shared_core` (cliente HTTP, modelos, estado de autenticação, Design System "Dark Premium" — ver `docs/15-design-system-e-padrao-crud.md`) — isso garante que `admin_web` e `student_web` nunca divirjam do contrato do backend nem da identidade visual.

## Backend: modular monolith

O backend **não** é microserviços — isso não se justifica no estágio atual e adicionaria complexidade operacional sem benefício real para o volume esperado. Em vez disso, é um **monolito modular**: cada domínio de negócio vive em `backend/src/modules/<dominio>/` com `controller` (HTTP), `service` (regra de negócio) e `dto` (validação/contrato via `class-validator`). Essa separação por módulo já deixa uma eventual extração futura (se algum dia necessária) mais barata, sem pagar o custo de microserviços hoje.

Módulos previstos (ver `docs/08-roadmap.md` para quando cada um é implementado):
`auth`, `academias`, `users`, `alunos`, `professores`, `planos`, `modalidades`, `agenda`, `financeiro`, `treinos`, `avisos`, `dashboard`, `backup`.

## Multi-tenant

Um único banco PostgreSQL, schema único. Toda entidade de negócio tem uma coluna `academiaId` (o tenant). Isso foi escolhido em vez de schema-por-tenant ou banco-por-tenant porque o produto é vendido para **centenas de academias**: um schema/banco único por cliente inviabilizaria migrations e operação em escala.

Isolamento em duas camadas:
1. **Nível de aplicação**: todo request autenticado carrega `academiaId` no JWT. Um `TenantContext` expõe esse valor aos services.
2. **Nível de query**: os services sempre filtram por `academiaId` — a partir do Sprint 1 isso é reforçado por um middleware/extension do Prisma que aplica o filtro automaticamente, para que um bug em um service não vaze dados entre academias.

`SYSTEM_ADMIN` é a exceção: `academiaId` nulo, acesso apenas a endpoints de gestão de tenants (`academias`).

## Storage desacoplado

Interface `StorageProvider` (`backend/src/storage/storage-provider.interface.ts`) com `upload`, `delete`, `getSignedUrl`. Implementada no Sprint 2 (primeiro uso real: logotipo da academia, ver `docs/13-admin-saas.md`) — usada por:
- **Uploads de usuário** (logo de academia hoje; foto de aluno/professor, fotos/vídeos de treino nos sprints seguintes) — `FileUploadService` (`backend/src/storage/file-upload.service.ts`) é a camada que o resto do sistema efetivamente chama, combinando `StorageProvider.upload()` com o registro de metadados no model `Arquivo`.
- **Backup** (`pg_dump` → zip → provider) — ver `docs/07-backups.md` (ainda não implementado).

Provider escolhido em runtime via `STORAGE_PROVIDER` (env var). Única implementação hoje: `local` (`LocalDiskStorageProvider`, grava num volume Docker persistente). `r2`/`s3`/`google-drive`/`minio`/`backblaze` já são valores válidos na validação de ambiente, mas sem implementação — selecioná-los falha alto e claro no boot. Nenhum módulo de negócio importa uma implementação concreta diretamente, só a interface/`FileUploadService` — trocar de provider é escrever uma nova classe, sem tocar em quem consome.

## Autorização

`RolesGuard` + decorator `@Roles(...)` por endpoint. Perfis: `SYSTEM_ADMIN`, `ACADEMIA_ADMIN`, `RECEPCIONISTA`, `PROFESSOR`, `ALUNO`. Detalhes em `docs/03-fluxo-autenticacao.md`.

## Comunicação

REST + Swagger (`/api/docs`). Sem GraphQL/tRPC — não há necessidade identificada.

## Status de implementação

- ✅ Sprint 0: fundação do monorepo, backend com health-check, workspace Flutter, Docker Compose local.
- Demais módulos: ver `docs/08-roadmap.md`.
