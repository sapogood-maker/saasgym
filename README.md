# SaaSGym

SaaS multi-tenant de gestão de academias.

- `backend/` — API REST (NestJS + Prisma + PostgreSQL)
- `admin_web/` — Painel administrativo (Flutter Web)
- `student_web/` — Portal do aluno (Flutter Web)
- `packages/shared_core/` — Código Dart compartilhado entre os dois frontends
- `infra/` — Docker Compose e configuração de ambiente
- `docs/` — Arquitetura, banco de dados, autenticação, API, Docker, deploy, backups e roadmap

Comece pela documentação em [`docs/`](docs/01-arquitetura.md).

## Quickstart (local)

```bash
# 1. Banco em Docker
cp infra/.env.example infra/.env
docker compose -f infra/docker-compose.yml --env-file infra/.env up postgres -d

# 2. Backend
cd backend
cp .env.example .env
npm install
npx prisma migrate deploy
npm run prisma:seed
npm run start:dev
# API em http://localhost:3000/api — Swagger em http://localhost:3000/api/docs

# 3. Frontends (em outros terminais)
cd admin_web && flutter pub get && flutter run -d chrome --web-port 5000
cd student_web && flutter pub get && flutter run -d chrome --web-port 5001
```

Para rodar tudo containerizado (mais próximo de produção), veja [`docs/05-docker.md`](docs/05-docker.md).

## Stack

Backend: NestJS, Prisma, PostgreSQL, JWT, Swagger, Docker.
Frontends: Flutter Web, Material 3, Riverpod, GoRouter.
Infra: Docker Compose, GitHub, Coolify.

## Roadmap

Ver [`docs/08-roadmap.md`](docs/08-roadmap.md).
