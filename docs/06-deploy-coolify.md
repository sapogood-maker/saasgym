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

## Deploy temporário por IP público (path-based, sem domínio)

Enquanto o domínio definitivo não é comprado, as 3 aplicações são publicadas
no mesmo IP do servidor (compartilhado com outras aplicações), usando **path**
em vez de subdomínio para não colidir com o roteamento das demais:

| Aplicação | Path público |
|---|---|
| `saasgym-admin-web` | `http://191.5.53.184/saasgym` |
| `saasgym-backend` | `http://191.5.53.184/saasgym-api` |
| `saasgym-student-web` | `http://191.5.53.184/student` |

Isso **não** é o modo nativo do Coolify (que roteia por domínio/Host), então
os labels do Traefik precisam ser escritos à mão em cada aplicação (aba
"Labels" de cada app no Coolify) em vez de deixar o Coolify gerar
automaticamente a partir de um domínio configurado.

### Build args (Flutter)

Em `saasgym-admin-web` e `saasgym-student-web`, seção de variáveis de build:

- `API_BASE_URL=http://191.5.53.184/saasgym-api`
- `BASE_HREF=/saasgym/` (admin_web) ou `BASE_HREF=/student/` (student_web)

`BASE_HREF` existe só para isso — sem ele, os assets do build Flutter
(`main.dart.js`, `canvaskit/`, etc.) são referenciados a partir de `/` e
quebram fora da raiz do domínio.

### Variável de ambiente do backend

Em `saasgym-backend`: `PUBLIC_API_PREFIX=/saasgym-api`.

Essa variável existe porque o backend, internamente, não sabe que está
atrás de um path externo — sem ela, dois comportamentos quebram
silenciosamente:
- o cookie de refresh token é gravado com `Path=/api/auth` (path interno),
  que nunca bate com a URL externa `/saasgym-api/auth/...` vista pelo
  navegador — o refresh silencioso falha e o usuário é deslogado ao expirar
  o access token;
- a URL de upload (logo da academia etc.) é gerada como `/uploads/...`, que
  não bate com nenhuma rota do Traefik e retorna 404.

`PUBLIC_API_PREFIX` resolve os dois: entra no `Path` do cookie e no prefixo
da URL de upload. Vazio (default) preserva o comportamento atual em
produção com domínio — só precisa ser preenchido neste cenário temporário.

### Labels do Traefik

`saasgym-admin-web` (container escuta na porta 80 via Nginx):

```
traefik.enable=true
traefik.http.routers.saasgym-admin.rule=PathPrefix(`/saasgym`)
traefik.http.routers.saasgym-admin.entrypoints=http
traefik.http.middlewares.saasgym-admin-strip.stripprefix.prefixes=/saasgym
traefik.http.routers.saasgym-admin.middlewares=saasgym-admin-strip
traefik.http.services.saasgym-admin.loadbalancer.server.port=80
```

`saasgym-student-web` (idem, trocando `/saasgym` por `/student`):

```
traefik.enable=true
traefik.http.routers.saasgym-student.rule=PathPrefix(`/student`)
traefik.http.routers.saasgym-student.entrypoints=http
traefik.http.middlewares.saasgym-student-strip.stripprefix.prefixes=/student
traefik.http.routers.saasgym-student.middlewares=saasgym-student-strip
traefik.http.services.saasgym-student.loadbalancer.server.port=80
```

`saasgym-backend` (porta 3000) precisa de **dois** roteadores: um mais
específico para `/uploads` (só remove o prefixo externo, sem recolocar
`/api` — os arquivos estáticos são servidos fora do prefixo `/api` pelo
Nest) e um genérico para o resto da API (remove o prefixo externo e
recoloca `/api`, que é o prefixo interno real das rotas):

```
traefik.enable=true

# Mais específico — precisa ter prioridade maior que o roteador genérico abaixo.
traefik.http.routers.saasgym-api-uploads.rule=PathPrefix(`/saasgym-api/uploads`)
traefik.http.routers.saasgym-api-uploads.entrypoints=http
traefik.http.routers.saasgym-api-uploads.priority=100
traefik.http.routers.saasgym-api-uploads.service=saasgym-api-svc
traefik.http.middlewares.saasgym-api-uploads-strip.stripprefix.prefixes=/saasgym-api
traefik.http.routers.saasgym-api-uploads.middlewares=saasgym-api-uploads-strip

# Genérico — /saasgym-api/auth/login vira /api/auth/login internamente.
traefik.http.routers.saasgym-api.rule=PathPrefix(`/saasgym-api`)
traefik.http.routers.saasgym-api.entrypoints=http
traefik.http.routers.saasgym-api.priority=50
traefik.http.routers.saasgym-api.service=saasgym-api-svc
traefik.http.middlewares.saasgym-api-strip.stripprefix.prefixes=/saasgym-api
traefik.http.middlewares.saasgym-api-addapi.addprefix.prefix=/api
traefik.http.routers.saasgym-api.middlewares=saasgym-api-strip,saasgym-api-addapi

traefik.http.services.saasgym-api-svc.loadbalancer.server.port=3000
```

### CORS

Não precisa adicionar o IP em `CORS_ORIGINS`: `admin_web`/`student_web` e o
`backend` estão sob o **mesmo host** (`191.5.53.184`), só o path muda — o
navegador trata isso como same-origin e não aplica CORS de jeito nenhum,
independente do que o servidor responda.

### Ao migrar para o domínio definitivo

1. Trocar `API_BASE_URL` dos dois builds Flutter para `https://api.saasgym.com` e `BASE_HREF` de volta para `/` (ou remover o build arg — `/` já é o default).
2. Remover `PUBLIC_API_PREFIX` do `saasgym-backend` (ou deixar vazio).
3. Remover os labels manuais do Traefik e configurar os domínios normalmente na aba "Domains" de cada aplicação — o Coolify volta a gerar o roteamento sozinho.
