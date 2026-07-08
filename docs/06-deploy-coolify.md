# Deploy (Coolify)

> **`infra/docker-compose.yml` é exclusivamente para desenvolvimento local.** Ele expõe a porta do PostgreSQL diretamente no host (`5432:5432`) e não tem nenhuma integração com o proxy reverso do Coolify — não aponte o Coolify para esse arquivo em produção. Em produção, use as **3 aplicações Coolify separadas** descritas abaixo, cada uma construída a partir do Dockerfile correspondente, com o PostgreSQL como recurso gerenciado à parte.

## Fluxo

```
GitHub (push em main) → webhook → Coolify → build da imagem → deploy automático
```

## Recomendação: 3 aplicações Coolify, 1 repositório

Em vez de um único recurso "docker-compose" no Coolify, criar **três aplicações separadas** apontando para o mesmo repositório GitHub, cada uma com seu próprio contexto/Dockerfile:

| Aplicação Coolify | Dockerfile | Contexto de build |
|---|---|---|
| `saasgym-backend` | `docker/backend.Dockerfile` | raiz do repo |
| `saasgym-admin-web` | `docker/admin_web.Dockerfile` | raiz do repo |
| `saasgym-student-web` | `docker/student_web.Dockerfile` | raiz do repo |

Isso permite deploy e rollback independentes por serviço (ex.: publicar só o backend sem rebuildar os dois frontends Flutter, que são mais lentos de compilar).

## PostgreSQL

Roda como recurso gerenciado do próprio Coolify (ou um serviço PostgreSQL externo), **não** dentro do mesmo compose da aplicação — separa o ciclo de vida do banco do ciclo de vida do código.

## Variáveis de ambiente

As mesmas de `infra/.env.example`, configuradas na UI do Coolify por aplicação:
- `saasgym-backend`: `DATABASE_URL`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `JWT_ACCESS_EXPIRATION`, `JWT_REFRESH_EXPIRATION`, `CORS_ORIGINS` (domínios reais de `admin_web`/`student_web` em produção), `PORT`.
- `saasgym-admin-web` / `saasgym-student-web`: sem variáveis de runtime (build Flutter Web é estático); a URL da API deve ser configurada em tempo de build se/quando os frontends passarem a precisar dela como constante (a definir com o módulo `auth` no Sprint 1).

**Nunca** commitar segredos reais — `infra/.env` e `backend/.env` estão no `.gitignore`; apenas os `.env.example` são versionados.

## Migrations em produção

O container do backend roda `prisma migrate deploy` automaticamente antes de iniciar a API (ver `docker/backend.Dockerfile`) — migrations pendentes são aplicadas a cada deploy, sem passo manual.

## CI/CD

Pipeline mínimo em `.github/workflows/` desde o Sprint 0 (lint + test + build do backend; `flutter analyze` + `flutter test` + `flutter build web` dos dois frontends). O deploy em si é acionado pelo webhook do Coolify no push para `main` — o CI do GitHub Actions é gate de qualidade, não o mecanismo de deploy.

## Portas e proxy reverso

Cada Dockerfile expõe uma única porta (`backend`: 3000, `admin_web`/`student_web`: 80 via Nginx). No modelo de "aplicação" do Coolify (não "docker-compose"), o Coolify detecta essa porta, gera o roteamento HTTPS via Traefik automaticamente e atribui o domínio configurado na UI — **não** é necessário (nem desejável) declarar labels de Traefik manualmente nos Dockerfiles. Os mapeamentos `ports:` do `infra/docker-compose.yml` (`3000:3000`, `5000:80`, `5001:80`) só fazem sentido no modo local; em produção o Coolify decide a porta pública.

## Restart policy

Os três serviços usam `restart: unless-stopped` — reinicia sozinho em caso de crash, mas não briga com uma parada manual (relevante ao dar `docker stop`/redeploy pelo Coolify). Mesmo padrão deve ser mantido se algum dia esse compose for usado como base de um recurso "Docker Compose" no Coolify.

## Persistência do PostgreSQL

Ao usar o PostgreSQL gerenciado pelo próprio Coolify (recomendado, não o `postgres` do `infra/docker-compose.yml`), a persistência e os backups automáticos de infraestrutura são responsabilidade do Coolify. **Isso não substitui o módulo `backup` do SaaSGym** (`docs/07-backups.md`), que existe para o dono de cada academia poder restaurar os dados do próprio negócio — são camadas complementares, não redundantes.

## Atualização / redeploy

- O backend roda `prisma migrate deploy` a cada boot (ver `docker/backend.Dockerfile`) — um redeploy comum (nova imagem, mesmo banco) aplica migrations pendentes automaticamente e é um no-op seguro se não houver nenhuma pendente.
- `admin_web`/`student_web` são builds estáticos: um redeploy troca os arquivos servidos pelo Nginx sem nenhum estado para migrar.
- **Risco a evitar**: nunca rodar `docker compose down -v` (ou equivalente) contra um ambiente com dados reais — o `-v` remove o volume `postgres_data`. Isso só é seguro no `infra/docker-compose.yml` local.
