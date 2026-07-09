# SaaSGym — Relatório Final do Sprint 3 (Cadastro de Alunos, Professores e Base Operacional da Academia)

**Data:** 2026-07-09
**Escopo:** primeiro sprint com valor direto para uma academia — CRUD de `Aluno` e `Professor`, dashboard da academia, perfil do usuário, e as primeiras telas reais do `admin_web` (login, navegação, CRUD, perfil, dashboard). Nenhum módulo além disso (Agenda, Financeiro, Planos da academia, Treinos, Portal do aluno, Pagamentos, Notificações — todos fora de escopo, por decisão explícita).
**Commits:** `020fcc6` (backend) + `0da9c83` (fix: normalização de CPF) + `ceeb07d` (frontend) + `3d7b6dc` (fix: IP/User-Agent na auditoria) — CI verde no GitHub Actions em todos os pushes.

---

## Valor entregue

### SYSTEM_ADMIN

Nenhuma funcionalidade nova diretamente — este sprint não é sobre a camada de administração do SaaS (já entregue no Sprint 2). O ganho indireto é que academias criadas por ele agora são utilizáveis de verdade: antes, uma academia recém-provisionada não tinha nada para fazer além de logar; agora, o `ACADEMIA_ADMIN` dessa academia consegue operar sozinho.

### ACADEMIA (`ACADEMIA_ADMIN`, `RECEPCIONISTA`)

- Cadastrar, editar, pesquisar, inativar/reativar e remover (soft delete) alunos e professores.
- Upload de foto de alunos e professores.
- Ver o dashboard da própria academia (total de alunos, ativos, professores, novos alunos do mês, aniversariantes, usuários do sistema).
- Editar o próprio nome, trocar a própria foto, trocar a própria senha.
- Tudo isso pela primeira vez através de uma **tela real** (`admin_web`), não só via API.

### PROFESSOR

- Ver (listar, detalhar, pesquisar) os alunos e professores da própria academia — leitura apenas, sem cadastrar/editar/remover.
- Editar o próprio nome, trocar a própria foto, trocar a própria senha (mesmo endpoint `/users/me` de qualquer usuário autenticado).
- **Sem acesso** ao dashboard da academia (restrito a `ACADEMIA_ADMIN`/`RECEPCIONISTA`) — decisão de escopo deste sprint, não uma lacuna.

### ALUNO

Nenhum ganho neste sprint — `Aluno` aqui é um registro administrativo (cadastro feito pela academia), não uma conta de login. Login/portal do aluno é o Sprint 10 (`docs/08-roadmap.md`).

---

## Fluxo do primeiro cliente

Validado de ponta a ponta contra o backend real via `docker compose up --build` (4 containers: postgres, backend, admin_web, student_web, todos saudáveis), usando a academia demo semeada (`admin@academiademo.com` / `ACADEMIA_ADMIN`), **sem qualquer intervenção do `SYSTEM_ADMIN`**:

| Passo | Resultado |
|---|---|
| ✅ Fazer login | `POST /auth/login` retorna access token + cookie de refresh httpOnly; CORS/`Set-Cookie` confirmados a partir da origem real do `admin_web` (`http://localhost:5000`) |
| ✅ Alterar seus dados | `PATCH /users/me` (nome) e `POST /users/me/foto` (avatar) confirmados |
| ✅ Cadastrar professor | `POST /professores` confirmado |
| ✅ Editar professor | `PATCH /professores/:id` confirmado |
| ✅ Pesquisar professor | `GET /professores?search=` confirmado por nome, CPF (com e sem máscara) e telefone |
| ✅ Cadastrar aluno | `POST /alunos` confirmado |
| ✅ Editar aluno | `PATCH /alunos/:id` confirmado |
| ✅ Pesquisar aluno | `GET /alunos?search=` confirmado por nome, CPF e telefone |
| ✅ Fazer upload das fotos | `POST /alunos/:id/foto`, `POST /professores/:id/foto` e `POST /users/me/foto` confirmados (arquivo real gravado, `fotoUrl` retornada) |
| ✅ Visualizar o dashboard | `GET /dashboard` confirmado refletindo as operações acima em tempo real |

**Ressalva de verificação**: o fluxo acima foi exercitado via chamadas HTTP reais contra o backend real (não mockado), incluindo CORS/cookies a partir da origem do `admin_web`. Não foi possível clicar na UI num navegador real (Chrome/Edge) — este ambiente de execução não tem display/browser headful disponível (`flutter run -d chrome` falha por essa razão, não por um problema do app). A cobertura de UI vem de: (a) testes de widget que exercitam o guard de rota e a renderização real das telas contra um `ProviderContainer` de verdade (não simulação superficial), (b) o bundle compilado sendo servido corretamente pelos containers Docker (200 em `/` e nos assets), (c) o fluxo de API completo acima, que é o que cada tela efetivamente chama.

---

## 1. Arquitetura implementada

```
backend/src/
├── common/
│   ├── validators/is-cpf.decorator.ts   @IsCPF() (módulo 11) + @NormalizeCPF()
│   ├── upload/image-file-interceptor.ts  extraído do Sprint 2 (era só do logo)
│   └── utils/request-metadata.ts         IP/User-Agent → AuditLog (novo)
└── modules/
    ├── alunos/            CRUD + pesquisa/paginação + status + soft delete + foto
    ├── professores/       mesmo padrão de alunos
    ├── dashboard/         GET /dashboard (distinto de /admin/dashboard, Sprint 2)
    └── users/             GET/PATCH /users/me, POST /users/me/foto

admin_web/lib/
├── routing/app_router.dart       guarda de rota reativa (redireciona sem sessão)
└── features/
    ├── auth/login_screen.dart
    ├── shell/app_shell.dart      navegação (Dashboard/Alunos/Professores/Perfil)
    ├── perfil/perfil_screen.dart
    ├── dashboard/dashboard_screen.dart
    ├── alunos/            lista + formulário + detalhe
    └── professores/       lista + formulário + detalhe

packages/shared_core/lib/src/
├── api/api_client.dart    + interceptor de refresh automático (novo)
├── auth/auth_api.dart     login/logout/changePassword (novo)
└── {alunos,professores,dashboard,users}/   modelos + API clients (novo)
```

**Decisões arquiteturais e por quê:**

- **Reaproveitamento total da infraestrutura congelada** (Sprints 1-2): `JwtAuthGuard`, `RolesGuard`, `AcademiaGuard`, `TenantContext`, `forTenant()`, `StorageProvider`/`FileUploadService`, `AuditService`. A única mudança na extensão de tenant do Prisma foi adicionar `Aluno`/`Professor` a `TENANT_SCOPED_MODELS` — exatamente o ponto de extensão que um comentário do Sprint 1 já previa.
- **Soft delete no service, não na extensão do Prisma** — `deletedAt: null` filtrado manualmente em toda leitura de `AlunosService`/`ProfessoresService`. Empilhar essa responsabilidade na extensão (já estendida para tenant nesta mesma sprint) misturaria duas preocupações na peça mais sensível do sistema, para economizar disciplina manual em só 2 services.
- **CPF único por academia, não globalmente** (`@@unique([academiaId, cpf])`) — a mesma pessoa pode, em tese, ser aluno em duas academias diferentes.
- **`ImageFileInterceptor` extraído** — existia só inline no upload de logo (Sprint 2); com 4 controllers agora usando a mesma validação de tipo/tamanho, virou um helper único, e o controller do Sprint 2 foi retrofitado para reaproveitá-lo.
- **`ApiClient` com interceptor de refresh e dedupe de chamadas concorrentes** — numa resposta 401 (exceto em `/auth/login`/`/auth/refresh`, para nunca entrar em loop), chama `/auth/refresh` uma vez só mesmo se várias requisições falharem ao mesmo tempo, e reexecuta cada uma com o novo token.

## 2. Endpoints criados

Ver `docs/14-alunos-professores.md` para a tabela completa com guards/papéis. Resumo: `POST/GET/GET-:id/PATCH/DELETE /alunos` + `/:id/status` + `/:id/foto` (mesmo padrão em `/professores`), `GET /dashboard`, `GET/PATCH /users/me` + `/users/me/foto`. Todos documentados no Swagger (`/api/docs`), confirmado via `/api/docs-json` — 18 rotas novas, todas com `security: [{bearer: []}]`, nenhuma pública.

## 3. Cobertura de testes

**219 testes automatizados** — 96 unitários (backend, sem alteração desde o Sprint 2) + **117 e2e** (backend, +36 desde o Sprint 2: 115 do commit inicial do sprint + 2 dos testes de normalização de CPF adicionados durante a validação final) + 4 de widget (`admin_web`) + 2 (`shared_core`). Suíte e2e confirmada **3 execuções consecutivas sem flakiness** (incluindo com `--runInBand=false`, forçando paralelismo real de workers — a mesma classe de problema encontrada e corrigida no Sprint 2).

| Camada | O que cobre |
|---|---|
| `is-cpf.decorator.spec.ts` (unit) | Algoritmo módulo 11 real, CPFs válidos conhecidos, sequências repetidas rejeitadas |
| `alunos.e2e-spec.ts` / `professores.e2e-spec.ts` | CRUD completo, matriz de permissões (401/403), CPF inválido→400/duplicado→409, isolamento entre tenants, pesquisa (nome/CPF com e sem máscara/telefone), paginação, soft delete (linha persiste com `deletedAt`), upload real (substituição remove o arquivo antigo), normalização de CPF fecha a brecha da constraint de unicidade |
| `dashboard.e2e-spec.ts` | Agregados corretos, aniversariantes via `$queryRaw` não vazam entre academias no mesmo mês |
| `users.e2e-spec.ts` | Perfil GET/PATCH, rejeita injeção de `role` via `forbidNonWhitelisted`, funciona para `SYSTEM_ADMIN` (sem `academiaId`), avatar, senha continua funcionando via `/auth/password` |
| Widget tests (`admin_web`) | Guarda de rota real (sem sessão → login; com sessão → shell), navegação até as listas de Alunos/Professores renderizando dados de uma API fake (sem rede) |

Testes rodados localmente (unit + e2e, 3x consecutivas), no CI (GitHub Actions, backend + flutter), e via Docker Compose real (fluxo de API completo, ver seção "Fluxo do primeiro cliente").

## 4. Riscos encontrados e corrigidos durante a implementação

| # | Achado | Como foi pego | Correção |
|---|---|---|---|
| 1 | **CPF armazenado exatamente como o cliente enviava** (com ou sem pontuação) — permitia burlar `@@unique([academiaId, cpf])` reenviando o mesmo CPF formatado diferente, e quebrava a pesquisa por CPF quando o formato buscado não batia com o armazenado | Validação manual do fluxo completo contra o backend real via Docker (não seria pego só rodando os testes existentes, que sempre usavam o mesmo formato em cada teste) | `@NormalizeCPF()` (remove pontuação antes de validar/persistir) aplicado às 4 DTOs de create/update; termo de busca por CPF também normalizado. Verificado com um teste de duplicidade cruzando formatos (`409`) e 2 novos testes e2e |
| 2 | **Auditoria de Alunos/Professores/Perfil não capturava IP/User-Agent** — só os eventos de autenticação (login/refresh/logout/troca de senha) capturavam, porque só o `AuthController` tinha acesso direto a `@Req()` com esse propósito; os controllers deste sprint nunca herdaram esse padrão | Revisão deliberada do requisito de auditoria do sprint ("IP" é campo obrigatório) contra o código real, não assumido como "provavelmente já funciona" | Helper `requestMetadata()` compartilhado; todos os métodos de escrita de `AlunosService`/`ProfessoresService`/`UsersService` passam a aceitar e repassar `{ipAddress, userAgent}`. Verificado no Postgres real (registros antigos com IP vazio, novos com IP populado) e coberto por asserções e2e |
| 3 | **`flutter test` quebrava ao importar `package:dio/browser.dart` incondicionalmente** — `flutter test` roda na Dart VM por padrão, não num navegador, e esse import usa APIs `dart:js_interop` inexistentes na VM | Rodar `flutter test` de verdade após implementar o interceptor de refresh (não assumido que compilaria) | Import condicional replicando o próprio padrão interno do pacote `dio` para o adapter de browser (`credentials_config_stub.dart`/`credentials_config_web.dart`) |
| 4 | **`flutter run -d chrome` falha neste ambiente** — sem display/browser headful disponível | Tentativa real de abrir a UI num navegador, 3 tentativas | Fallback para `flutter run -d web-server` + verificação via `curl` de que o bundle compilado serve corretamente; transparecido como limitação de verificação, não maquiado como "testado no navegador" |

## 5. Avaliação de segurança

- Todos os 18 endpoints novos exigem JWT (`security: [{bearer: []}]` no Swagger, confirmado programaticamente); nenhum usa `@Public()`.
- `AlunosController`/`ProfessoresController`/`DashboardController` — `AcademiaGuard` + `RolesGuard` em todos, confirmado no código e via matriz de testes 401/403 (inclusive `SYSTEM_ADMIN` bloqueado por não ter `academiaId`, e `ALUNO` bloqueado por não estar em nenhum `@Roles`).
- `UsersController` **deliberadamente sem** `AcademiaGuard` (precisa funcionar para `SYSTEM_ADMIN` também, mesmo padrão de `/auth/me`) — ainda assim protegido pelo `JwtAuthGuard` global (registrado via `APP_GUARD` em `auth.module.ts`), confirmado.
- Tenant isolation: `Aluno`/`Professor` em `TENANT_SCOPED_MODELS`, testado (`prisma-tenant-extension.e2e-spec.ts` + testes próprios de isolamento em cada módulo) — uma academia nunca vê/edita/deleta registro de outra, mesmo pedindo o id diretamente (404, não 403 — não revela que o recurso existe).
- Upload validado por MIME type e tamanho antes de qualquer escrita em disco (mesmo `ImageFileInterceptor` do Sprint 2, agora compartilhado); nome físico sempre UUID.
- Auditoria completa (usuário, academia, IP, User-Agent, data, entidade, alteração) em toda escrita, após a correção do item 2 dos riscos acima.

## 6. Avaliação de arquitetura

- Zero alterações em `JwtAuthGuard`, `RolesGuard`, `SystemAdminGuard`, `TenantContextService`, `PrismaService.forTenant()` (lógica), `AllExceptionsFilter`, `ThrottlerModule` — reaproveitamento comprovado, não só planejado.
- A única mudança na peça mais sensível (extensão de tenant do Prisma) foi uma linha (adicionar 2 models a um `Set`), exatamente como o comentário do Sprint 1 previa.
- Padrão idêntico entre `AlunosModule`/`ProfessoresModule` (mesma forma de DTOs, service, controller, testes) — reduz custo cognitivo de manutenção e facilita o próximo módulo de negócio similar.
- Frontend: `ApiClient`/`AuthApi`/modelos de domínio ficam em `shared_core`, reaproveitáveis por `student_web` quando o portal do aluno chegar (Sprint 10) — nenhuma tela do `admin_web` reimplementa lógica de HTTP.

## 7. Melhorias futuras (não bloqueantes)

1. `AlunosController`/`ProfessoresController` ainda não permitem que um `PROFESSOR` veja só os próprios alunos vinculados — hoje é "todos os alunos da academia" para qualquer leitor autorizado; vínculo aluno↔professor é trabalho do Sprint 5+ (Agenda/`Turma`).
2. Máscara de CPF/telefone no formulário do `admin_web` é responsabilidade do usuário digitar corretamente — não há input mask automática ainda; o backend tolera qualquer formatação (normaliza), mas a UX poderia formatar em tempo real.
3. Detalhe de Aluno/Professor não mostra histórico de auditoria própria (quem editou, quando) — dado já existe em `AuditLog`, falta só a tela.
4. `file_picker` na Web não valida tamanho antes do upload (só o backend valida e rejeita) — uma checagem client-side evitaria um upload desnecessário de arquivo grande.

## 8. Nota geral do Sprint

| Critério | Nota | Justificativa |
|---|---|---|
| **Arquitetura** | **9,5/10** | Reaproveitamento comprovado (não só planejado) de toda a infraestrutura congelada; único ponto de extensão tocado foi exatamente o previsto desde o Sprint 1. |
| **Segurança** | **9,5/10** | Todos os endpoints comprovadamente autenticados e autorizados corretamente; auditoria completa (após a correção do achado #2); meio ponto a menos por essa lacuna ter existido até a validação final, em vez de já nascer correta. |
| **Cobertura de testes** | **9,5/10** | 219 testes, incluindo os cenários mais sensíveis (isolamento entre tenants, normalização de CPF fechando uma brecha real de unicidade, upload binário real), 3 execuções consecutivas sem flakiness sob paralelismo real — mas dois achados reais (CPF, auditoria) só apareceram na validação manual de ponta a ponta, não na primeira rodada de testes escritos junto com o código. |
| **Valor entregue** | **10/10** | Critério novo a partir deste sprint (política definida pelo usuário) — checklist "Fluxo do primeiro cliente" 100% validado contra o backend real, sem intervenção do `SYSTEM_ADMIN`. |
| **Nota geral** | **9,5/10** | Sprint entregue dentro do escopo exato pedido, com dois achados reais de qualidade (CPF, auditoria) encontrados por verificação de ponta a ponta — não por sorte — e corrigidos com testes de regressão antes do fechamento. |

---

## Conclusão

Uma academia recém-criada pelo `SYSTEM_ADMIN` agora consegue operar sozinha: logar, gerenciar seus próprios alunos e professores, ver seu dashboard e cuidar do próprio perfil — tudo validado de ponta a ponta contra o backend real via Docker, sem nenhuma intervenção administrativa. A infraestrutura dos Sprints 1-2 provou seu valor sendo reaproveitada sem alteração de lógica; a única mudança na peça mais sensível (isolamento de tenant) foi de uma linha, exatamente onde já estava previsto. Dois bugs reais (normalização de CPF, captura de IP na auditoria) foram encontrados pela mesma disciplina que pegou os bugs do Sprint 2 — rodar de verdade, contra infraestrutura real, mais de uma vez — e corrigidos com testes de regressão antes de considerar o sprint fechado.
