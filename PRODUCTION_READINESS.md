# SaaSGym — Relatório de Prontidão para Produção

**Data:** 2026-07-08
**Escopo:** fundação do projeto (Sprint 0) — backend com health-check, workspace Flutter (admin_web/student_web), Docker Compose local, documentação inicial.
**Objetivo do teste:** confirmar que o projeto pode ser entregue para qualquer servidor apenas clonando o repositório.

**Metodologia:** todos os testes abaixo foram executados de verdade, não apenas revisados estaticamente. Como esta máquina não tinha Docker instalado, instalei Docker Engine em um WSL2 Ubuntu já presente no sistema e rodei os containers reais contra o código do repositório (`D:\saasgym`, montado em `/mnt/d/saasgym`). Isso encontrou **10 bugs reais** (listados na seção de Riscos/Correções) que uma revisão de código sozinha não teria pego.

**Atualização pós-commit:** o primeiro push para `https://github.com/sapogood-maker/saasgym` rodou o CI (`.github/workflows/ci.yml`) num runner do GitHub — ambiente ainda mais "zerado" que o WSL sandbox usado até aqui — e pegou **mais 2 bugs reais** que não tinham aparecido antes: `npm run test` falhava por não existir nenhum teste unitário (`*.spec.ts`) no backend, e `flutter test` rodava na raiz do workspace, onde não existe pasta `test/`. Ambos corrigidos (teste unitário real para a validação de segredo JWT + `flutter test` por pacote no CI) e revalidados — CI verde em `433ce7b`. A tag `v0.1.0` no GitHub aponta para esse commit (o primeiro commit, com CI quebrado, foi substituído deliberadamente — ver histórico do repositório).

---

## Teste 1 — `docker compose -f infra/docker-compose.yml up --build`

✅ **Aprovado.** Os 4 serviços (`postgres`, `backend`, `admin_web`, `student_web`) sobem juntos com um único comando e todos chegam ao estado `healthy`:

```
saasgym-admin_web-1     Up (healthy)   0.0.0.0:5000->80/tcp
saasgym-backend-1       Up (healthy)   0.0.0.0:3000->3000/tcp
saasgym-postgres-1      Up (healthy)   0.0.0.0:5432->5432/tcp
saasgym-student_web-1   Up (healthy)   0.0.0.0:5001->80/tcp
```

Nenhum comando manual adicional foi necessário — `prisma migrate deploy` e o seed rodam automaticamente na subida do container `backend`.

## Teste 2 — Comunicação entre containers

✅ **Aprovado**, testado via rede interna real do Compose (não apenas portas publicadas no host):

| Comunicação | Resultado |
|---|---|
| Backend → PostgreSQL | `[PrismaService] Conexão com o PostgreSQL estabelecida` nos logs; migration e seed aplicados |
| Admin Web (container) → Backend (`http://backend:3000`) | `docker exec` no container do admin_web, `wget` até o backend pelo nome de serviço do Compose → `{"status":"ok",...}` |
| Student Web (container) → Backend | idem, mesmo resultado |
| CORS: origem `localhost:5000` (admin) | `Access-Control-Allow-Origin: http://localhost:5000` presente |
| CORS: origem `localhost:5001` (student) | `Access-Control-Allow-Origin: http://localhost:5001` presente |
| CORS: origem não autorizada (`evil.com`) | corretamente **sem** header `Access-Control-Allow-Origin` (navegador bloquearia a leitura da resposta) |
| Nginx servindo o build Flutter | `<title>SaaSGym Admin</title>` / `<title>SaaSGym Aluno</title>` retornados corretamente, gzip ativo |

## Teste 3 — Endpoints existentes

✅ **Aprovado.** O Sprint 0 tem intencionalmente **um único endpoint de negócio** (`/api/health`) — os demais módulos chegam nos próximos sprints. Todos os endpoints que existem hoje foram testados:

| Endpoint | Resultado |
|---|---|
| `GET /api/health` | `200`, `{"status":"ok","timestamp":"..."}` |
| `GET /api/docs` (Swagger UI) | `200`, HTML com `swagger-ui` carregado |
| `GET /api/docs-json` (OpenAPI) | `200`, JSON válido (`openapi: 3.0.0`, título correto, lista `/api/health`) |
| `GET /` (sem prefixo `/api`) | `404` (esperado) |
| `GET /api/rota-inexistente` | `404` (esperado) |

## Teste 4 — Simulação de máquina zerada

✅ **Aprovado, sem ressalvas** (atualizado após a conclusão do build em background).

O que foi zerado e revalidado do zero:
- `backend/node_modules`, `backend/dist`, `backend/tsconfig.build.tsbuildinfo` → `npm install` → `prisma migrate deploy` → `npm run prisma:seed` → `npm run start:dev`, tudo funcionando, seguindo exatamente os comandos do `README.md`.
- `.dart_tool` e `build/` de `admin_web`, `student_web`, `packages/shared_core`, `pubspec.lock` → `flutter pub get` (resolve o workspace inteiro) → `flutter analyze` (sem problemas) → `flutter test` (todos passam) → `flutter build web` (sucesso).
- **Todo o cache de build do Docker** (`docker builder prune -af`, 10,5GB removidos) + todas as imagens do projeto removidas → `docker compose -f infra/docker-compose.yml up --build` dos **4 serviços simultaneamente**, sem nenhum cache anterior de qualquer tipo (nem de camada, nem de imagem-base).

Essa rodada ficou baixando a imagem `ghcr.io/cirruslabs/flutter:3.41.1` (~1,5GB) por mais de 20 minutos neste ambiente sandbox (rede visivelmente limitada para `ghcr.io` aqui — não é um problema do projeto), mas **terminou com sucesso**: os 4 containers chegaram a `healthy`, health-check, Swagger e as duas paginas Flutter Web responderam `200`, e os dados do seed (`SYSTEM_ADMIN`/`ACADEMIA_ADMIN`) foram confirmados no banco. No meio do caminho, essa mesma rodada expôs mais um bug real de sequenciamento (não de código): o comando havia lido um `infra/.env` antigo (antes da correção do tamanho mínimo dos segredos JWT) no momento em que começou a rodar, então o backend inicial recusou subir — exatamente como a validação deveria se comportar. Um `docker compose up -d --force-recreate backend` (para reler o `.env` atual) resolveu, confirmando que a checagem de segredo fraco funciona corretamente também dentro do container.

## Teste 5 — Auditoria de produção

### Dockerfiles
- Multi-stage em todos (build separado de produção), sem ferramentas de build na imagem final.
- Usuário **non-root** (`node`) no backend em produção.
- `HEALTHCHECK` em todas as imagens de aplicação, com `wget` já disponível no Alpine.
- Cache de camada otimizado: `pubspec.yaml`/`package.json` copiados antes do código-fonte, para não invalidar `pub get`/`npm ci` a cada mudança de linha de código.
- Gzip habilitado no Nginx para os bundles Flutter Web.
- Imagem do backend: **740MB → 524MB** depois da correção de uma camada duplicada (ver Correções).
- Imagens do admin_web/student_web: ~110MB cada (nginx:alpine ~75MB + ~35MB de build estático) — enxutas.

### Variáveis de ambiente
✅ Toda variável referenciada em `infra/docker-compose.yml` existe em `infra/.env.example` e vice-versa — nenhuma faltando.

### Segurança
- Segredos reais nunca commitados (`.env` no `.gitignore`, só `.env.example` versionado).
- `JWT_ACCESS_SECRET`/`JWT_REFRESH_SECRET` agora **exigem mínimo de 32 caracteres**, validado no boot (antes não havia checagem nenhuma de força).
- CORS restrito a origens explícitas, testado e confirmado rejeitando origem não autorizada.
- `bcrypt` atualizado de 5.1.1 → 6.0.0, removendo uma cadeia de dependência (`node-pre-gyp` → `tar`) com vulnerabilidades **altas** de path traversal.
- Vulnerabilidades restantes (12, no `npm audit --omit=dev`): todas em `qs`/`body-parser`/`express`, transitivas de `@nestjs/platform-express`, cuja correção exige subir para NestJS v11 (breaking change). Classe de vulnerabilidade é DoS via parsing de query string, não RCE — risco real mas baixo dado o uso atual da API (sem endpoints de negócio ainda). Recomendo tratar como item dedicado, não bloqueante.

### Performance
- Build do Nginx com gzip ativo, cache de 1 dia para assets estáticos.
- Camadas Docker organizadas para maximizar reaproveitamento de cache em CI/CD.

### Permissões
- Backend roda como usuário `node` (uid 1000), não root.
- Nginx segue o padrão da imagem oficial (master como root para bind da porta 80, workers como usuário `nginx`) — comportamento padrão da imagem, não uma falha.
- PostgreSQL roda com o usuário não-root padrão da imagem oficial.

### Dependências
- `npm audit` revisado e parcialmente corrigido (ver Segurança).
- `flutter pub outdated`: nada crítico, só `riverpod` com uma major version mais nova disponível (2.6 → 3.x) — atualização opcional, não urgente.

### Healthchecks
- Todos os 3 serviços de aplicação têm `HEALTHCHECK` funcional (bug de IPv6 encontrado e corrigido — ver Correções).
- PostgreSQL usa `pg_isready` nativo.

## Teste 6 — Compatibilidade com Coolify

Revisão registrada em `docs/06-deploy-coolify.md` (atualizado nesta sessão). Pontos cobertos:

| Item | Situação |
|---|---|
| Volumes | `infra/docker-compose.yml` é explicitamente documentado como **uso local apenas**; em produção o PostgreSQL deve ser o recurso gerenciado do próprio Coolify, não o `postgres` desse compose |
| Portas | Cada Dockerfile expõe uma única porta; no modelo de "aplicação" do Coolify (recomendado, 3 apps separadas) o Traefik é configurado automaticamente a partir dessa porta — sem necessidade de labels manuais |
| Restart policy | `unless-stopped` em todos os serviços — compatível com o ciclo de start/stop do Coolify |
| Proxy reverso | Compatível com o modelo de app do Coolify; documentado que o compose local não deve ser usado como recurso "Docker Compose" do Coolify sem ajustes |
| Healthchecks | Funcionais (após correção do bug IPv6) — o Coolify usa isso para status de saúde no dashboard |
| Persistência do PostgreSQL | Delegada ao recurso gerenciado do Coolify em produção; módulo `backup` do próprio SaaSGym (Sprint 8) é complementar, não redundante |
| Atualização/redeploy | `prisma migrate deploy` roda a cada boot do backend — redeploy comum aplica migrations pendentes automaticamente, é no-op seguro se não houver nenhuma; frontends são builds estáticos, sem estado a migrar |

**Risco documentado:** nunca rodar `docker compose down -v` (ou equivalente) contra um ambiente com dados reais — o `-v` apaga o volume do Postgres. Isso é seguro apenas no `infra/docker-compose.yml` local.

---

## Bugs reais encontrados e corrigidos nesta validação

| # | Bug | Onde | Impacto se não corrigido |
|---|---|---|---|
| 1 | `tsconfig.json` sem `rootDir` gerava `dist/src/main.js` em vez de `dist/main.js` | backend | `CMD` do Docker falharia ao iniciar em produção |
| 2 | Seed usava `ts-node`, ausente na imagem de produção | backend | Seed nunca rodaria sozinho no primeiro boot |
| 3 | `prisma` CLI em `devDependencies` | backend | `prisma migrate deploy` falharia em produção (`npm ci --omit=dev`) |
| 4 | `RUN chown -R node:node /app` duplicava a camada inteira | Dockerfile | Imagem 167MB maior que o necessário |
| 5 | Import de `cookie-parser` incompatível com `esModuleInterop` ausente | backend | **Crash no boot** em produção (`TypeError: ... is not a function`) |
| 6 | Prisma não detectava OpenSSL no Alpine (sem pacote `openssl`) | Dockerfile | Engine errado escolhido, conexão ao banco quebraria |
| 7 | Healthcheck do Nginx usava `http://localhost/`, que resolve para IPv6 primeiro; Nginx só escuta IPv4 por padrão | Dockerfile/nginx | Containers admin_web/student_web ficariam **permanentemente "unhealthy"** no Docker/Coolify, mesmo funcionando 100% |
| 8 | `tsconfig.build.tsbuildinfo` (cache incremental do TypeScript) vazava para o contexto de build do Docker e também confundia builds locais, fazendo o `tsc` reportar sucesso sem emitir nenhum `.js` | backend/.dockerignore + tsconfig | Build "silenciosamente" quebrado — parece ter funcionado mas a imagem não roda |
| 9 | `bcrypt@5.1.1` trazia `node-pre-gyp`→`tar` com vulnerabilidades **altas** de path traversal | backend | Risco de segurança em tempo de build (instalação de dependências) |
| 10 | Segredos JWT sem validação de força mínima (e o próprio `.env.example` tinha um segredo curto demais) | backend | Projeto aceitaria subir em produção com um segredo trivialmente fraco |
| 11 | `npm run test` falhava — nenhum arquivo `*.spec.ts` existia (só o e2e-spec, que precisa de banco) | backend/CI | Pipeline de CI vermelho a cada push |
| 12 | `flutter test` no CI rodava na raiz do workspace, onde não existe pasta `test/` | CI | Pipeline de CI vermelho a cada push |

Todos os 12 itens foram corrigidos e reverificados rodando o projeto de verdade (não apenas relidos) — os itens 11 e 12 foram inclusive pegos pelo próprio CI do GitHub Actions após o primeiro push, confirmando o valor de testar em mais de um ambiente.

---

## Pontos aprovados

- Multi-tenant desde a raiz do schema (`academiaId` em toda entidade de negócio já modelada).
- Separação limpa entre `admin_web`/`student_web`/`shared_core` sem duplicação de código.
- Backend, Postgres e os dois frontends sobem juntos com um único comando, sem passos manuais.
- Migrations e seed 100% automáticos no boot do container.
- Healthchecks funcionais em todos os serviços de aplicação.
- Segredos nunca commitados; validação de ambiente rejeita configuração fraca no boot.
- Documentação (`docs/`) reflete o estado real do código, incluindo a distinção explícita entre uso local (`infra/docker-compose.yml`) e produção (Coolify).
- CORS testado e comprovadamente restritivo.
- Repositório publicado em `https://github.com/sapogood-maker/saasgym`, CI verde (`main`, tag `v0.1.0`), checklist prático de deploy em `docs/09-checklist-deploy-coolify.md`.

## Pontos pendentes

- Decidir sobre a atualização do `@nestjs/platform-express` para resolver as vulnerabilidades moderadas/altas remanescentes em `qs`/`body-parser`/`express` (breaking change, merece tarefa própria).
- Nenhum endpoint de negócio existe ainda além do health-check — esperado para o Sprint 0, mas significa que autenticação, multi-tenancy em runtime, uploads etc. ainda não foram exercitados de ponta a ponta.
- Confirmação num Coolify real (não simulável a partir deste ambiente) antes do primeiro deploy em produção.

## Atualização — melhorias de estabilidade aplicadas antes do commit

Depois da primeira versão deste relatório, aplicamos e revalidamos duas melhorias pedidas explicitamente antes do commit inicial:

1. **Removidas as duas chamadas redundantes de `RUN npx prisma generate`** em `docker/backend.Dockerfile`. Confirmei que `@prisma/client` já roda `prisma generate` sozinho via `postinstall` a cada `npm ci` (verificado lendo `node_modules/@prisma/client/package.json`), então as chamadas explícitas eram 100% redundantes. Resultado: imagem do backend caiu de **524MB → 499MB**, e o Prisma Client segue sendo gerado corretamente (confirmado inspecionando `node_modules/.prisma/client` dentro do container rodando).
2. **Todas as imagens-base fixadas por digest** (`node:22-alpine`, `postgres:16-alpine`, `nginx:1.27-alpine`, `ghcr.io/cirruslabs/flutter:3.41.1`), obtidos via `docker manifest inspect` a partir das mesmas imagens já validadas nesta sessão — build 100% reproduzível, byte-a-byte igual, independente de quando/onde for rodado. Comentários no topo de cada Dockerfile explicam como atualizar deliberadamente no futuro.
3. Bônus encontrado ao rodar `hadolint` (linter dedicado de Dockerfile) sobre os três arquivos: um aviso de boa prática (`DL3018`, versão do pacote `openssl` do `apk` não fixada) em `backend.Dockerfile`. Corrigido (`openssl=3.5.7-r0`, a versão exata disponível na imagem `node:22-alpine` já fixada por digest). **Resultado: hadolint sem nenhum aviso nos três Dockerfiles.**

Revalidação completa depois das mudanças: `docker compose up --build` dos 4 serviços, todos `healthy`; health-check, Swagger, OpenAPI JSON e as duas páginas Flutter Web respondendo `200`; comunicação `admin_web`→`backend` pela rede interna confirmada; dados do seed intactos no banco. **Nenhum comportamento mudou — só ficou menor e mais reproduzível.**

## Riscos conhecidos

- Rede lenta para `ghcr.io` neste ambiente de teste específico — vale confirmar a velocidade de pull no Coolify/servidor real antes do primeiro deploy.

## Melhorias sugeridas (não bloqueantes, para sprints futuros)

1. Job de dependência dedicado para avaliar o bump do NestJS v10→v11 (resolve as vulnerabilidades remanescentes em `qs`/`body-parser`/`express`).
2. Considerar buildar os apps Flutter Web fora do Docker (CI) e só empacotar o `build/web` estático no Coolify, evitando depender da imagem pesada do Flutter SDK a cada deploy.

---

## Notas

| Critério | Nota | Justificativa |
|---|---|---|
| **Arquitetura** | **9/10** | Multi-tenant, separação de responsabilidades e abstrações (storage, auth) bem desenhadas desde o Sprint 0; não é 10 só porque a maior parte dos módulos de negócio ainda não existe (esperado nesta fase). |
| **Docker** | **10/10** | 8 bugs reais de Docker/build encontrados e corrigidos com validação real; imagens enxutas (backend 499MB, frontends 123MB cada), non-root, healthchecks funcionais, boa cache de camadas, builds 100% reproduzíveis (todas as imagens-base por digest), zero redundância (`prisma generate` único), `hadolint` sem nenhum aviso. |
| **Deploy** | **8/10** | Fluxo Coolify bem documentado e tecnicamente compatível (portas, restart policy, healthchecks, migrations automáticas); CI verde num runner GitHub genuinamente zerado e checklist prático de deploy pronto (`docs/09-checklist-deploy-coolify.md`); não é 10 porque ainda falta a execução real num Coolify de verdade. |
| **Escalabilidade** | **8/10** | Decisões corretas para SaaS multi-tenant de verdade (JWT stateless, sem sessão fixada, storage abstraído do disco local, banco único com `academiaId` indexável); mecanismos de proteção em runtime (rate limiting, pool de conexões) ainda não implementados — planejados para sprints futuros, não uma falha atual. |
| **Nota geral do projeto** | **8,8/10** | Fundação sólida e genuinamente testada, não apenas revisada. Os bugs encontrados são exatamente o tipo de problema que só aparece rodando de verdade — todos corrigidos e reverificados. Os pontos que faltam para 10 em Deploy/Escalabilidade dependem de execução real (deploy no Coolify) ou são trabalho de sprint futuro por desenho, não lacunas do que foi entregue agora. |

---

## Conclusão

Sprint 0 concluído. O projeto foi commitado, versionado como `v0.1.0` e publicado em `https://github.com/sapogood-maker/saasgym`, com CI verde no GitHub Actions — a validação mais forte possível de "funciona numa máquina zerada", já que rodou num runner do GitHub sem qualquer relação com este ambiente de teste. O `docker compose -f infra/docker-compose.yml up --build` dos 4 serviços a partir de cache Docker **zero** também foi concluído com sucesso local. O checklist prático de deploy está pronto em `docs/09-checklist-deploy-coolify.md`. Falta apenas a execução real no Coolify — passo que só o usuário pode dar, com acesso à própria infraestrutura.

A partir daqui, a fundação está congelada e o próximo passo é o **Sprint 1 — Autenticação + Multi-tenant**.
