# Changelog

Registra o fim de cada sprint — o que foi entregue e onde encontrar o relatório completo. Não é um changelog por commit; é um changelog por marco.

## v0.3.0 — Sprint 3: Cadastro de Alunos, Professores e Base Operacional da Academia

Primeiro sprint com valor direto para uma academia: até aqui (Sprints 0-2), tudo era fundação técnica ou administração 100% restrita a `SYSTEM_ADMIN`. A partir daqui, uma academia criada pelo `SYSTEM_ADMIN` consegue logar e operar sozinha — cadastrar/editar/pesquisar alunos e professores, fazer upload de foto, editar o próprio perfil, ver seu dashboard — sem qualquer intervenção do `SYSTEM_ADMIN`.

Backend: CRUD completo de `Aluno` e `Professor` (tenant-scoped, soft delete, pesquisa e paginação, upload de foto via `StorageProvider`), dashboard da academia (`GET /dashboard`), perfil do usuário (`/users/me`). Reaproveita 100% da infraestrutura congelada dos Sprints 1-2 (`JwtAuthGuard`, `RolesGuard`, `AcademiaGuard`, `TenantContext`, `forTenant()`, `StorageProvider`, `AuditLog`) — a única alteração na extensão de tenant do Prisma foi adicionar `Aluno`/`Professor` à lista de models já prevista para isso desde o Sprint 1.

Frontend: primeiras telas reais do `admin_web` (Sprints 0-2 tinham só um placeholder) — login com refresh automático de token, guarda de rota, shell de navegação, CRUD de alunos/professores com upload de foto, perfil e dashboard, todos consumindo a API real.

Durante a validação de ponta a ponta via Docker Compose, um bug real foi encontrado e corrigido: CPF era armazenado exatamente como o cliente enviava (com ou sem pontuação), o que permitia burlar a constraint de unicidade por academia reenviando o mesmo CPF formatado diferente, e quebrava a pesquisa por CPF quando o formato buscado não batia com o armazenado. Corrigido com normalização (só dígitos) antes de validar/persistir/pesquisar. Também foi corrigida uma lacuna de auditoria: os módulos de negócio deste sprint não capturavam IP/User-Agent (só os eventos de autenticação capturavam) — agora capturam, em toda operação de escrita.

Relatório completo: [`SPRINT3_REPORT.md`](SPRINT3_REPORT.md). Documentação: [`docs/14-alunos-professores.md`](docs/14-alunos-professores.md).

## v0.2.1 — Sprint 2: Administração do SaaS

Módulo `admin` (100% `SYSTEM_ADMIN`): cadastro e ciclo de vida de academias (`AcademiaProvisioningService`, transacional — cria academia + primeiro admin + configuração numa única operação); status da academia (`TRIAL`/`ATIVA`/`SUSPENSA`/`BLOQUEADA`/`CANCELADA`) aplicado em login/refresh com revogação de sessão em cascata; `AcademiaConfiguracao` (branding); `PlanoSaas` (catálogo comercial do próprio SaaS, sem cobrança ainda); primeira implementação real de `StorageProvider` (`LocalDiskStorageProvider`) com primeiro uso (logo da academia); dashboard do `SYSTEM_ADMIN` (visão cross-tenant da plataforma).

Relatório completo: [`SPRINT2_REPORT.md`](SPRINT2_REPORT.md). Documentação: [`docs/13-admin-saas.md`](docs/13-admin-saas.md).

## v0.2.0 — Sprint 1: Autenticação, Autorização e Multi-Tenant

Camada de identidade completa sobre a fundação do Sprint 0: login/logout/refresh (com rotação e detecção de reuso), troca de senha, guards e decorators reutilizáveis (`JwtAuthGuard`, `RolesGuard`, `AcademiaGuard`, `SystemAdminGuard`), `TenantContext` (AsyncLocalStorage) + extensão do Prisma com isolamento automático por `academiaId`, auditoria (`AuditLog`), hardening (Helmet, rate limiting, filtro global de exceções), CI com Postgres de serviço + e2e.

Antes de congelar, uma revisão arquitetural dedicada (segurança, acoplamento, duplicação, performance, riscos para os módulos de negócio futuros) encontrou e corrigiu 5 problemas reais — o mais importante: um vazamento cross-tenant no `upsert` da extensão do Prisma, que não tinha isolamento nenhum antes da correção.

A partir daqui, a camada de autenticação está **congelada**: novos módulos reutilizam essa infraestrutura (guards, decorators, `forTenant()`, `TenantContext`) em vez de recriá-la ou alterá-la sem necessidade.

Relatório completo: [`SPRINT1_REPORT.md`](SPRINT1_REPORT.md). Documentação: [`docs/10-auth.md`](docs/10-auth.md), [`docs/11-security.md`](docs/11-security.md), [`docs/12-multi-tenant.md`](docs/12-multi-tenant.md).

## v0.1.0 — Sprint 0: Fundação

Estrutura do monorepo (NestJS + Prisma + PostgreSQL; Flutter Web `admin_web`/`student_web`/`shared_core` via Melos); Docker Compose local; deploy no Coolify; CI no GitHub Actions; documentação base.

Relatório completo: [`PRODUCTION_READINESS.md`](PRODUCTION_READINESS.md). Checklist de deploy: [`docs/09-checklist-deploy-coolify.md`](docs/09-checklist-deploy-coolify.md).
