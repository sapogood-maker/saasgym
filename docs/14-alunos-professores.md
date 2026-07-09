# Alunos, Professores, Dashboard da Academia e Perfil

Implementado no Sprint 3 (`backend/src/modules/{alunos,professores,dashboard,users}/`) — primeiro sprint que entrega valor direto para uma academia: até aqui, toda infraestrutura (Sprints 0-2) era ou fundação técnica, ou 100% restrita a `SYSTEM_ADMIN`. A partir deste sprint, uma academia criada via `POST /admin/academias` consegue logar e operar sozinha, sem qualquer intervenção do `SYSTEM_ADMIN`.

## Endpoints

Todos exigem `Authorization: Bearer <accessToken>` (JWT global) e estão documentados no Swagger.

| Endpoint | Guards | Papéis |
|---|---|---|
| `POST/GET /alunos`, `GET/PATCH /alunos/:id`, `PATCH /alunos/:id/status`, `DELETE /alunos/:id`, `POST /alunos/:id/foto` | `AcademiaGuard` + `RolesGuard` | Escrita: `ACADEMIA_ADMIN`, `RECEPCIONISTA`. Leitura: também `PROFESSOR` |
| Mesmo padrão em `/professores` | idem | idem |
| `GET /dashboard` | `AcademiaGuard` + `RolesGuard` | `ACADEMIA_ADMIN`, `RECEPCIONISTA` |
| `GET/PATCH /users/me`, `POST /users/me/foto` | `JwtAuthGuard` (global, **sem** `AcademiaGuard`) | Qualquer usuário autenticado, incluindo `SYSTEM_ADMIN` |

`SYSTEM_ADMIN` e `ALUNO` nunca têm acesso a `/alunos`, `/professores` ou `/dashboard` — bloqueados pelo `AcademiaGuard` (`SYSTEM_ADMIN` não tem `academiaId`) e pelo `RolesGuard` (`ALUNO` não está em nenhuma lista de `@Roles`), respectivamente.

## Aluno e Professor

Dois models tenant-scoped novos (entraram em `TENANT_SCOPED_MODELS`, a única mudança na extensão do Prisma congelada desde o Sprint 1 — extensão exatamente prevista por um comentário deixado ali). Campos em `backend/prisma/schema.prisma` (`Aluno`/`Professor`); ver `docs/02-banco-de-dados.md`.

- **CPF**: validado por `@IsCPF()` (algoritmo real de dígito verificador, módulo 11 — não é checagem de formato) e normalizado (`@NormalizeCPF()`, remove pontuação) antes de validar e persistir. `@@unique([academiaId, cpf])` — único dentro da academia, não globalmente: a mesma pessoa pode, em tese, ser aluno em duas academias diferentes. A normalização evita que a mesma constraint seja burlada reenviando o CPF com formatação diferente.
- **Status**: reaproveita o enum `UserStatus` (`ATIVO`/`INATIVO`) já existente — sem duplicar um enum idêntico.
- **Soft delete**: `deletedAt` filtrado no **service** (`deletedAt: null` em toda leitura), não na extensão do Prisma — decisão deliberada de não empilhar duas responsabilidades (isolamento de tenant + soft delete) na peça mais sensível do sistema.
- **Foto**: `fotoArquivoId` → `Arquivo` (mesmo model de upload do Sprint 2). `POST /alunos/:id/foto` e `POST /professores/:id/foto` substituem a foto anterior (arquivo antigo é removido do storage).
- Cadastro **administrativo apenas** — `Aluno`/`Professor` não criam conta de login. Login próprio (portal do aluno) é trabalho do Sprint 10.

## Pesquisa e paginação

`GET /alunos`/`GET /professores` aceitam `?search=&status=&page=&pageSize=`. `search` faz `OR` de `contains` (case-insensitive) em nome/CPF/telefone — o termo de busca é normalizado (dígitos apenas) antes de comparar com o CPF armazenado, para que buscar `"111.444.777-35"` e `"11144477735"` encontrem o mesmo cadastro.

## Dashboard da academia

`GET /dashboard` — distinto de `GET /admin/dashboard` (Sprint 2, `SYSTEM_ADMIN`, visão cross-tenant da plataforma). Agregados reais, escopados à academia do usuário autenticado: total de alunos, alunos ativos, total de professores, novos alunos do mês, aniversariantes do mês, usuários do sistema. Ainda sem Agenda/Financeiro (chegam em sprints futuros).

Aniversariantes do mês usa `$queryRaw` (Prisma não expressa filtro por mês de uma coluna `DateTime` no query builder) com placeholders parametrizados (`Prisma.sql`, nunca concatenação de string) e `academiaId` explícito na cláusula `WHERE` — SQL bruto não passa pela extensão de tenant automática, então o escopo é manual e coberto por teste e2e provando que não vaza entre academias.

## Perfil do usuário (`/users/me`)

Mesmo padrão de `GET /auth/me` (Sprint 1): funciona para qualquer usuário autenticado, incluindo `SYSTEM_ADMIN`, por isso **sem** `AcademiaGuard`. Permite editar o próprio nome e trocar a própria foto — nunca e-mail (identificador de login) ou `role` (`UpdateUserProfileDto` só tem `nome`; `ValidationPipe` com `forbidNonWhitelisted: true` rejeita qualquer campo extra). Troca de senha **não duplicada aqui** — reaproveita `PATCH /auth/password`, já existente desde o Sprint 1.

## Auditoria

Toda operação de escrita (`Cadastrar`, `Editar`, `Inativar/Reativar`, `Remover`, `Upload de foto`) gera `AuditLog` com usuário, academia, IP, User-Agent, data e a alteração realizada (`metadata`). IP/User-Agent são extraídos da requisição pelo controller (`requestMetadata()`, `backend/src/common/utils/request-metadata.ts`) e repassados ao service — até então, só os eventos de autenticação (login/refresh/logout/troca de senha) capturavam esses dois campos; agora os módulos de negócio também capturam.

## Upload de foto

Primeiro uso **completo** do `StorageProvider` (upload de logo, Sprint 2, foi o primeiro uso, mas só de uma categoria). Três categorias novas em `ArquivoCategoria`: `ALUNO_FOTO`, `PROFESSOR_FOTO`, `USER_AVATAR`, cada uma com sua própria pasta em `LocalDiskStorageProvider`. Validação de tipo (PNG/JPEG/WebP) e tamanho (até 2MB) via `ImageFileInterceptor` — helper compartilhado extraído neste sprint (antes só existia inline no upload de logo do Sprint 2, que foi retrofitado para reaproveitá-lo).

## Frontend (`admin_web`)

Primeiras telas reais do projeto (Sprints 0-2 eram 100% backend, exceto um placeholder de dashboard):

- **`ApiClient`** (`packages/shared_core`) ganhou um interceptor de refresh automático: numa resposta 401 (exceto em `/auth/login`/`/auth/refresh`, para nunca entrar em loop), chama `/auth/refresh` uma vez e reexecuta a requisição original; chamadas concorrentes que falham ao mesmo tempo compartilham a mesma renovação de token.
- **Login** + **guarda de rota** (`go_router`, redireciona para `/login` sem sessão e para `/` se já autenticado) + **shell de navegação** (Dashboard/Alunos/Professores/Perfil).
- **Perfil**: editar nome, trocar foto (upload real via `file_picker`), trocar senha (reaproveita `PATCH /auth/password`).
- **Dashboard**: consome `GET /dashboard` de verdade.
- **Alunos/Professores**: lista (busca com debounce + filtro de status + paginação), formulário de criação/edição (upload de foto), detalhe (editar/inativar-reativar/remover).

## O que este sprint explicitamente não implementa

Agenda, Financeiro, Planos da academia (`Plano`, distinto de `PlanoSaas`), Treinos, Portal do aluno, Pagamentos, Notificações — todos em sprints futuros (`docs/08-roadmap.md`).
