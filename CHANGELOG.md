# Changelog

Registra o fim de cada sprint — o que foi entregue e onde encontrar o relatório completo. Não é um changelog por commit; é um changelog por marco.

## v0.2.0 — Sprint 1: Autenticação, Autorização e Multi-Tenant

Camada de identidade completa sobre a fundação do Sprint 0: login/logout/refresh (com rotação e detecção de reuso), troca de senha, guards e decorators reutilizáveis (`JwtAuthGuard`, `RolesGuard`, `AcademiaGuard`, `SystemAdminGuard`), `TenantContext` (AsyncLocalStorage) + extensão do Prisma com isolamento automático por `academiaId`, auditoria (`AuditLog`), hardening (Helmet, rate limiting, filtro global de exceções), CI com Postgres de serviço + e2e.

Antes de congelar, uma revisão arquitetural dedicada (segurança, acoplamento, duplicação, performance, riscos para os módulos de negócio futuros) encontrou e corrigiu 5 problemas reais — o mais importante: um vazamento cross-tenant no `upsert` da extensão do Prisma, que não tinha isolamento nenhum antes da correção.

A partir daqui, a camada de autenticação está **congelada**: novos módulos reutilizam essa infraestrutura (guards, decorators, `forTenant()`, `TenantContext`) em vez de recriá-la ou alterá-la sem necessidade.

Relatório completo: [`SPRINT1_REPORT.md`](SPRINT1_REPORT.md). Documentação: [`docs/10-auth.md`](docs/10-auth.md), [`docs/11-security.md`](docs/11-security.md), [`docs/12-multi-tenant.md`](docs/12-multi-tenant.md).

## v0.1.0 — Sprint 0: Fundação

Estrutura do monorepo (NestJS + Prisma + PostgreSQL; Flutter Web `admin_web`/`student_web`/`shared_core` via Melos); Docker Compose local; deploy no Coolify; CI no GitHub Actions; documentação base.

Relatório completo: [`PRODUCTION_READINESS.md`](PRODUCTION_READINESS.md). Checklist de deploy: [`docs/09-checklist-deploy-coolify.md`](docs/09-checklist-deploy-coolify.md).
