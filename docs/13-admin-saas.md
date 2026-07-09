# Administração do SaaS

Implementado no Sprint 2 (`backend/src/modules/admin/`). Módulo **100% restrito a `SYSTEM_ADMIN`** — todo endpoint aqui usa `SystemAdminGuard`; nenhum usuário de academia (`ACADEMIA_ADMIN`, `PROFESSOR`, `RECEPCIONISTA`, `ALUNO`) tem acesso.

## Endpoints

Todos em `/api/admin`, documentados no Swagger.

| Endpoint | Descrição |
|---|---|
| `POST /admin/academias` | Cria academia + primeiro `ACADEMIA_ADMIN` + configuração inicial, numa transação |
| `GET /admin/academias` | Lista, paginada, filtro por `status` |
| `GET /admin/academias/:id` | Detalhe |
| `PATCH /admin/academias/:id` | Edita campos cadastrais |
| `PATCH /admin/academias/:id/status` | Transição de status — revoga sessões em cascata se o novo status bloquear acesso |
| `GET`/`PUT /admin/academias/:id/configuracao` | Branding (logo, cores, redes sociais, PIX, horário) |
| `POST /admin/academias/:id/logo` | Upload do logotipo (PNG/JPEG/WebP, até 2MB) |
| `GET`/`POST`/`PATCH /admin/planos-saas` | Catálogo de planos comerciais do SaaS (sem delete) |
| `GET /admin/dashboard` | Visão geral: academias por status, armazenamento usado, versão instalada |

## Provisionamento de academia

`AcademiaProvisioningService` (`backend/src/modules/admin/academias/academia-provisioning.service.ts`) — cria `Academia` + primeiro `User` (`ACADEMIA_ADMIN`) + `AcademiaConfiguracao` vazia numa única `$transaction`: qualquer falha (ex.: e-mail do admin já existe) reverte tudo, nunca deixando uma academia parcialmente criada.

- `status` nasce `TRIAL`, `trialExpiresAt` = agora + `TRIAL_DURATION_DAYS` (default 14 dias).
- `planoSaasId` é o informado ou, por padrão, o plano chamado `"Trial"` do catálogo.
- Ao final da transação, o admin criado já consegue logar imediatamente — sem nenhum passo manual.

Depois do commit (nunca dentro da transação):
1. Auditoria (`ACADEMIA_CREATED`) — chamada direta, garantida.
2. Evento de domínio `academia.provisionada` via `@nestjs/event-emitter` — hoje sem nenhum listener (não é um placeholder fingindo funcionalidade, é um evento real e testado que simplesmente ainda não tem consumidor). Ponto de extensão para passos futuros (e-mail de boas-vindas etc.) sem acoplar nada ao endpoint ou a este service.

## Status da academia

`AcademiaStatus`: `TRIAL | ATIVA | SUSPENSA | BLOQUEADA | CANCELADA`.

- `TRIAL`/`ATIVA`: acesso normal.
- `SUSPENSA`: bloqueio reversível (ex.: pendência de pagamento).
- `BLOQUEADA`: bloqueio por decisão administrativa.
- `CANCELADA`: encerramento do relacionamento.

`SUSPENSA`/`BLOQUEADA`/`CANCELADA` bloqueiam **login e refresh** (`AuthService`, ver `docs/11-security.md`) e, ao entrar num desses estados via `PATCH /admin/academias/:id/status`, revogam em cascata todos os refresh tokens de todos os usuários da academia — fechando o acesso em, no máximo, a vida do access token já emitido (≤15min), não os 7 dias de vida do refresh token.

Toda transição é auditada (`ACADEMIA_STATUS_CHANGED`) com `statusAnterior`, `statusNovo`, `motivo` (opcional, informado pelo `SYSTEM_ADMIN`) e `sessoesRevogadas`.

## Planos SaaS

`PlanoSaas` — catálogo comercial do próprio SaaS (Free/Trial/Basic/Professional/Enterprise, seedados com limites de exemplo), **não confundir com o `Plano` de negócio** (mensalidade que uma academia vende para seus alunos, entidade de um sprint futuro) — nomes deliberadamente distintos para nunca colidir.

Campos `limite*` (`limiteAlunos`, `limiteProfessores`, `limiteUsuarios`, `limiteArmazenamentoMb`, `limiteBackups`): `null` = ilimitado. **Sem enforcement nesta sprint** — os números existem na estrutura, mas nada ainda compara contagem real contra eles (não há `Aluno`/`Professor` ainda). A comparação é trabalho natural do sprint que criar essas entidades, usando exatamente esses limites já modelados. Sem delete — `ativo: false` é como um plano "sai" da oferta sem quebrar a FK de academias que já o usam.

## Storage

Primeiro uso real do `StorageProvider` (interface desenhada desde o Sprint 0, ver `docs/01-arquitetura.md`): upload de logotipo. `LocalDiskStorageProvider` grava num volume Docker persistente (`uploads_data`, montado em `/app/uploads`), organizado por categoria (`ArquivoCategoria` — só `ACADEMIA_LOGO` nesta sprint), nome físico sempre UUID. Metadados (nome original, mime type, tamanho, provider) vão para o model `Arquivo`, reaproveitável por qualquer upload futuro (foto de aluno/professor, mídia de exercício, documentos).

Seleção de provider via `STORAGE_PROVIDER` (env var, default `local`) — trocar para R2/S3/MinIO/Backblaze no futuro é escrever uma nova classe da interface, sem tocar em `FileUploadService` nem em quem o chama. Nenhum módulo de negócio importa `LocalDiskStorageProvider` diretamente.

Achado real durante a implementação: o volume Docker nomeado é criado pelo Docker como `root` por padrão; o container roda como usuário `node` (não-root, ver `docker/backend.Dockerfile`). Sem pré-criar `/app/uploads` na imagem com o dono certo, o primeiro upload falhava com `EACCES`. Corrigido no Dockerfile — ver `docs/09-checklist-deploy-coolify.md` para o passo equivalente no Coolify.

## Dashboard

`GET /admin/dashboard` — agregados **reais**, sem dado fictício:
- `totalAcademias`, `academiasPorStatus` (contagem real via `groupBy`).
- `armazenamentoUsadoBytes` — soma real de `Arquivo.tamanhoBytes`.
- `backups` — `{ disponivel: false, quantidade: 0 }`, honesto: o módulo `backup` ainda não existe (ver `docs/08-roadmap.md`); nenhum número inventado.
- `versaoInstalada` — lida de `package.json` em tempo de execução.

## Segurança

Ver `docs/11-security.md` para a aplicação do status no login/refresh e o trade-off de janela de acesso (mesma classe do trade-off JWT stateless já aceito no Sprint 1).
