# Docker (ambiente local)

## Pré-requisitos

Docker Desktop (ou Docker Engine + Compose plugin).

## Subir o ambiente completo

```bash
cp infra/.env.example infra/.env    # ajuste os valores se necessário
docker compose -f infra/docker-compose.yml --env-file infra/.env up --build
```

Serviços:

| Serviço | URL local | Descrição |
|---|---|---|
| `postgres` | `localhost:5432` | PostgreSQL 16 |
| `backend` | `http://localhost:3000/api` (Swagger em `/api/docs`) | API NestJS |
| `admin_web` | `http://localhost:5000` | Painel administrativo (build Flutter Web servido por Nginx) |
| `student_web` | `http://localhost:5001` | Portal do aluno (idem) |

Migrations do Prisma são aplicadas automaticamente na subida do container `backend` (`prisma migrate deploy`).

## Workflow de desenvolvimento do dia a dia

Rodar `admin_web`/`student_web` via `docker compose` reconstrói o build Flutter Web a cada mudança — lento para iterar. No dia a dia:

```bash
# Só o banco em Docker:
docker compose -f infra/docker-compose.yml --env-file infra/.env up postgres -d

# Backend com hot-reload, fora do Docker:
cd backend && cp .env.example .env && npm install && npm run start:dev

# Frontends com hot-reload, fora do Docker:
cd admin_web && flutter run -d chrome --web-port 5000
cd student_web && flutter run -d chrome --web-port 5001
```

Use `docker compose up --build` (todos os serviços containerizados) apenas para validar o comportamento de produção localmente antes de um deploy.

## Dockerfiles

- `docker/backend.Dockerfile` — build multi-stage Node 22 Alpine; gera o Prisma Client, compila e roda `prisma migrate deploy` antes de subir a API.
- `docker/admin_web.Dockerfile` / `docker/student_web.Dockerfile` — build multi-stage com a imagem `cirruslabs/flutter` (compila o app Flutter Web) e produção servida por Nginx (`docker/nginx/spa.conf`, com fallback de rotas para `index.html` — necessário para o GoRouter).

Todos os Dockerfiles usam `context: ..` (raiz do monorepo) no `docker-compose.yml`, porque `admin_web`/`student_web` dependem de `packages/shared_core` via Dart pub workspace.
