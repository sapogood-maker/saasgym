# Checklist de Deploy — Coolify

Repositório: `https://github.com/sapogood-maker/saasgym` (branch `main`).

Este checklist assume o modelo já documentado em `docs/06-deploy-coolify.md`: **3 aplicações Coolify separadas** + **1 recurso PostgreSQL gerenciado**, todas apontando para o mesmo repositório. Não use `infra/docker-compose.yml` diretamente no Coolify — ele é só para desenvolvimento local.

## 1. PostgreSQL (criar primeiro)

- [ ] No Coolify: **New Resource → Database → PostgreSQL** (versão 16).
- [ ] Anotar a `DATABASE_URL` interna gerada pelo Coolify (formato `postgresql://user:pass@host:5432/db`).
- [ ] Confirmar que o backup automático do Coolify para esse banco está ativo (proteção de infraestrutura — complementar ao módulo `backup` do próprio SaaSGym, ainda não implementado — ver `docs/08-roadmap.md`).

## 2. Backend (`saasgym-backend`)

- [ ] **New Resource → Application → Dockerfile** (ou "Docker Compose" apontando só para o serviço `backend`, se preferir — mas o caminho mais simples é uma aplicação Dockerfile dedicada).
- [ ] Repositório: `sapogood-maker/saasgym`, branch `main`.
- [ ] Dockerfile path: `docker/backend.Dockerfile`.
- [ ] **Build context: raiz do repositório** (não `backend/`) — o Dockerfile faz `COPY backend/...` a partir da raiz.
- [ ] Porta exposta: `3000`.
- [ ] Variáveis de ambiente (gerar segredos novos, não reaproveitar os do `.env.example`):

  | Variável | Valor |
  |---|---|
  | `NODE_ENV` | `production` |
  | `PORT` | `3000` |
  | `DATABASE_URL` | a do passo 1 |
  | `JWT_ACCESS_SECRET` | `openssl rand -base64 32` (mínimo 32 caracteres — validado no boot) |
  | `JWT_REFRESH_SECRET` | `openssl rand -base64 32` (diferente do access) |
  | `JWT_ACCESS_EXPIRATION` | `15m` |
  | `JWT_REFRESH_EXPIRATION` | `7d` |
  | `CORS_ORIGINS` | os domínios reais do admin_web e student_web (passo 3 e 4), separados por vírgula — sem `http://localhost` |
  | `STORAGE_PROVIDER` | `local` (única implementação disponível — ver `docs/13-admin-saas.md`) |
  | `TRIAL_DURATION_DAYS` | `14` (ou o valor desejado) |

- [ ] **Volume persistente**: montar um volume em `/app/uploads` (Coolify → aba "Storages" da aplicação → "Add Volume", destino `/app/uploads`). Sem isso, todo logo/arquivo enviado é perdido no próximo deploy — o filesystem do container não é persistente por padrão.
- [ ] Deploy e conferir nos logs: `Applying migration...` → `Seed concluído` → `Nest application successfully started`.
- [ ] Testar `https://<domínio-backend>/api/health` → `{"status":"ok",...}`.
- [ ] Testar `https://<domínio-backend>/api/docs` (Swagger).
- [ ] Testar upload real: `POST /api/admin/academias/:id/logo` seguido de `GET` na URL retornada — se der `EACCES` no log, o volume foi criado com dono `root` e o container roda como usuário `node` (não-root); recriar o volume costuma resolver (o Dockerfile já pré-cria `/app/uploads` com o dono certo, mas um volume manual criado antes dessa correção pode reter a permissão antiga).

## 3. Admin Web (`saasgym-admin-web`)

- [ ] **New Resource → Application → Dockerfile**.
- [ ] Dockerfile path: `docker/admin_web.Dockerfile`, build context: raiz do repositório.
- [ ] Porta exposta: `80`.
- [ ] Sem variáveis de runtime necessárias (build estático).
- [ ] Deploy e testar `https://<domínio-admin>/` (deve carregar a tela "SaaSGym — Painel Administrativo").
- [ ] Testar uma rota inexistente (ex.: `/qualquer-coisa`) — deve devolver a mesma página (fallback do GoRouter), não 404.

## 4. Student Web (`saasgym-student-web`)

- [ ] Mesmo processo do passo 3, com `docker/student_web.Dockerfile`.

## 5. Depois que os 3 domínios existirem

- [ ] Voltar em `saasgym-backend` e atualizar `CORS_ORIGINS` com os domínios reais de `admin_web`/`student_web` (passo 2 pede isso antes deles existirem — é normal precisar voltar aqui).
- [ ] Redeploy do backend para aplicar a variável atualizada.
- [ ] Testar CORS de verdade: abrir o admin_web no navegador, confirmar no DevTools que uma chamada à API não é bloqueada.

## 6. Webhook de deploy automático

- [ ] Confirmar que os 3 recursos Coolify têm o webhook do GitHub configurado (deploy automático a cada push em `main`) — normalmente já vem pronto ao criar a aplicação a partir de um repo GitHub conectado via GitHub App do Coolify.

## 7. Checklist pós-deploy

- [ ] `GET /api/health` — `200`.
- [ ] `GET /api/docs` — Swagger carrega.
- [ ] `POST /api/auth/login` com as credenciais do seed (`admin@saasgym.com`) — `200` com `accessToken`.
- [ ] `POST /api/admin/academias` autenticado como `SYSTEM_ADMIN` — cria academia de verdade, admin criado já consegue logar.
- [ ] Confirmar nos 3 recursos que o healthcheck do Coolify mostra "Healthy" no dashboard.
- [ ] Confirmar que `docker compose down -v` **nunca** deve ser usado contra o Postgres de produção (isso só existe no `infra/docker-compose.yml` local).

## Erros esperados e como diagnosticar

| Sintoma | Causa provável |
|---|---|
| Backend não sobe, log menciona `JWT_ACCESS_SECRET` | Segredo com menos de 32 caracteres — gerar um novo com `openssl rand -base64 32` |
| Backend sobe mas `admin_web` não consegue chamar a API (erro de CORS no console do navegador) | `CORS_ORIGINS` do backend não inclui o domínio real do `admin_web` — ver passo 5 |
| `admin_web`/`student_web` mostram 404 em rotas internas do app (ex. após dar refresh numa rota) | Verificar se o Coolify está de fato usando `docker/nginx/spa.conf` (fallback SPA) — não deveria acontecer se o Dockerfile não foi alterado |
| Migration falha no boot do backend | Verificar se `DATABASE_URL` aponta para o Postgres certo e se o Coolify liberou a conexão de rede entre os recursos |
