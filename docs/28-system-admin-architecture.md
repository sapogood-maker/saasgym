# Arquitetura do System Admin

Documento de decisão arquitetural — 2026-07-16. Não é uma sprint executada: formaliza uma decisão de produto antes de qualquer implementação, para servir de referência às sprints que a partir daqui vão construir o System Admin. Não altera código, autenticação, telas ou schema — só descreve o desenho acordado.

**Decisão central**: o System Admin deixa de ser "uma seção do SaaSGym restrita a `SYSTEM_ADMIN`" e passa a ser **um produto separado**, com frontend próprio, destinado exclusivamente ao dono da plataforma e à futura equipe de suporte. O SaaSGym continua sendo, exclusivamente, o ERP multi-tenant que as academias usam.

## 1. Objetivo do System Admin

Administrar a plataforma SaaS como um todo — não uma academia específica. Quem usa o System Admin não gerencia alunos, turmas ou mensalidades de ninguém; gerencia **tenants** (academias como clientes do SaaS), o catálogo comercial, o ciclo de vida comercial de cada conta (trial → ativa → suspensa/bloqueada/cancelada) e, quando necessário, presta suporte técnico dentro de uma academia específica via impersonação.

Público: hoje, só o proprietário da plataforma (`SYSTEM_ADMIN`). O documento já reserva um lugar para uma futura equipe de suporte (seção 8) sem implementá-lo agora.

## 2. Limites entre SaaSGym e System Admin

| | SaaSGym | System Admin |
|---|---|---|
| Quem usa | Dono/equipe de cada academia (`ACADEMIA_ADMIN`, `RECEPCIONISTA`, `PROFESSOR`) e alunos (`ALUNO`) | Dono da plataforma (`SYSTEM_ADMIN`) e, no futuro, suporte |
| Escopo de dado | Uma academia (`academiaId` sempre presente) | Todas as academias (`academiaId` nulo, exceto durante impersonação — seção 7) |
| Frontend | `admin_web` (academia) + `student_web` (aluno) | Novo app, próprio (seção 4) |
| Aparece na navegação de qual app | — | Nunca em `admin_web`/`student_web` — nenhum item de menu, nenhuma rota alcançável por um usuário de academia, em nenhum papel |
| Autenticação | Mesmo `POST /api/auth/login`, mesmo `User`, mesmo JWT | Mesmo mecanismo — ver seção 9 sobre por quê |

O critério de separação não é tecnológico (os dois podem — e vão, inicialmente — compartilhar backend, banco e autenticação), é **de produto**: são dois públicos que nunca se cruzam, duas propostas de valor diferentes, dois roadmaps que evoluem em velocidades diferentes. Empacotar os dois numa mesma UI (mesmo que atrás de um guard de role) tende a vazar decisões de design de um produto para o outro — exatamente o tipo de acoplamento que este documento existe para evitar antes que aconteça.

## 3. O que pertence ao SaaSGym

Tudo que já existe hoje em `admin_web`/`student_web`/módulos de negócio do backend, sem mudança nenhuma proposta por este documento:

- `admin_web`: Dashboard, Alunos, Professores, Planos, Matrículas, Financeiro (Mensalidades/Caixa/Painel), Agenda (Modalidades/Turmas/Calendário/Reposições), Avaliação Física, Relatórios, Perfil.
- `student_web`: portal do aluno (planejado, Sprint 10 do roadmap — `docs/08-roadmap.md`).
- Backend: `alunos`, `professores`, `planos`, `matriculas`, `financeiro`, `agenda`, `avaliacoes-fisicas`, `relatorios`, `users` (perfil), `notifications` — todos tenant-scoped, protegidos por `AcademiaGuard` + `RolesGuard`.
- `packages/shared_core` continua compartilhado **entre `admin_web` e `student_web`** — ver seção 4 sobre se o System Admin também reaproveita esse pacote.

Nenhum desses módulos ganha uma tela ou rota visível a `SYSTEM_ADMIN` dentro do `admin_web`. Isso já é verdade hoje (não há nenhum item de sidebar nem rota em `admin_web/lib/routing/app_router.dart` voltado a `SYSTEM_ADMIN`) — este documento formaliza isso como invariante de produto, não como lacuna a preencher.

## 4. O que pertence ao System Admin

**Novo app Flutter Web**, irmão de `admin_web`/`student_web` no mesmo monorepo — ex.: `system_admin_web/` — não uma tela a mais dentro do `admin_web`. O workspace Melos já suporta múltiplos apps Flutter; adicionar um terceiro é o mesmo padrão já usado para `student_web`.

- **Reaproveita `packages/shared_core`** para o que é genuinamente compartilhável e não vaza acoplamento: cliente HTTP (`ApiClient`/`dio`), `authSessionProvider`, tokens do Design System (`AppColorScheme`, `AppTypography`, `AppSpacing` — a paleta "Dark Premium" pode/deve ser a mesma, é identidade visual da empresa, não da academia). **Não reaproveita** modelos/APIs de domínio de academia (`Aluno`, `Matricula`, `RelatoriosApi` etc.) — o System Admin não tem motivo para importar esses módulos.
- Módulos de negócio do backend que já pertencem a ele hoje, sob `backend/src/modules/admin/` (`docs/13-admin-saas.md`): `academias` (CRUD + status + configuração), `planos-saas` (catálogo comercial), `dashboard` (visão agregada da plataforma).
- Módulos novos, propostos por este documento (sem implementação ainda): aprovação de trial (seção 6), impersonação (seção 7), auditoria cross-tenant (visualizar `AuditLog` de qualquer academia).
- Protegido, do início ao fim, por `SystemAdminGuard` (já existe, `docs/12-multi-tenant.md`) — nenhum endpoint novo do System Admin é acessível sem `role === SYSTEM_ADMIN`.

### Por que o backend continua sendo o mesmo NestJS, não um serviço separado

O pedido diz "poderá utilizar a mesma infraestrutura... porém será tratado como um produto separado". A leitura adotada aqui: **separação de produto/frontend, não separação de serviço/deploy** — pelos mesmos motivos que já levaram o projeto a ser um monolito modular (`docs/01-arquitetura.md`):

- O mecanismo de tenant (`TenantContext`, `PrismaService.forTenant()`) já trata `SYSTEM_ADMIN` como caso especial (`academiaId` nulo, sem filtro) — é infraestrutura que o System Admin **precisa** e que já existe, sem duplicar.
- `AuditLog` cross-tenant, autenticação, rate limiting, `AllExceptionsFilter` — tudo isso teria que ser recriado (ou replicado) num backend separado, sem ganho correspondente no estágio atual (uma instância, sem exigência de compliance de isolamento físico).
- O módulo `admin` já vive isolado por namespace (`/api/admin`, só controllers/services próprios) dentro do monolito — o "produto separado" já tem uma fronteira de código limpa hoje. Extrair isso para um serviço/deploy próprio é uma migração possível no futuro (ex.: se o time de suporte crescer e precisar de um ciclo de deploy independente do SaaSGym, ou se surgir exigência de isolar dados operacionais da plataforma fisicamente), não uma necessidade atual — decisão explicitamente adiada, não descartada.

## 5. Fluxo de criação de uma nova academia

Já implementado (`AcademiaProvisioningService`, `docs/13-admin-saas.md`) — este documento não muda o fluxo, só define onde ele passa a viver na UI:

1. `SYSTEM_ADMIN` aciona `POST /admin/academias` (hoje via API/Swagger; passa a ser um formulário na tela "Academias" do novo System Admin) — dados da academia + primeiro `ACADEMIA_ADMIN`.
2. Numa única transação: cria `Academia` (`status = TRIAL`, `trialExpiresAt = agora + 14 dias`), o primeiro `User` (`ACADEMIA_ADMIN`) e uma `AcademiaConfiguracao` vazia. Falha em qualquer etapa reverte tudo.
3. Depois do commit: auditoria (`ACADEMIA_CREATED`) + evento `academia.provisionada` (hoje sem listener — ponto de extensão já existente para e-mail de boas-vindas).
4. O admin criado já consegue logar imediatamente no `admin_web` — nenhum passo manual adicional.

Criação continua **sempre iniciada pelo `SYSTEM_ADMIN`** — não existe (nem este documento propõe) cadastro público de auto-signup. Essa distinção importa para a seção 6.

## 6. Fluxo de aprovação de trial

**Estado atual: não existe uma etapa de aprovação separada, porque não existe auto-signup.** Como toda academia nasce de uma ação manual do `SYSTEM_ADMIN` (seção 5), a criação **é** a aprovação — não há uma fila de pedidos pendentes para revisar. `AcademiaStatus.TRIAL` hoje significa "trial já em andamento", não "aguardando aprovação".

Este documento propõe manter essa semântica como está — **não criar um estado de aprovação para um fluxo que ainda não existe** (auto-signup não está no roadmap atual, `docs/08-roadmap.md`). Fica registrado como ponto de extensão, para quando/se o auto-signup for decidido:

- Um novo valor de `AcademiaStatus` (ex.: `PENDENTE_APROVACAO`) precederia `TRIAL`, criado por um endpoint público de cadastro (sem autenticação, distinto de `POST /admin/academias`), sem login liberado para o `ACADEMIA_ADMIN` recém-criado até a aprovação.
- O System Admin ganharia uma tela "Solicitações pendentes" — listar, aprovar (transiciona `PENDENTE_APROVACAO → TRIAL`, dispara o e-mail de boas-vindas via o mesmo evento `academia.provisionada` que já existe) ou rejeitar (mantém bloqueado, sem soft-delete automático).
- Isso é uma migration (`AcademiaStatus`) e dois endpoints novos — explicitamente **fora do escopo deste documento** (nenhuma migration, nenhum código, por pedido explícito).

O que fica decidido agora, sem precisar de código: **quando esse fluxo existir, ele é um sub-módulo do System Admin, nunca do `admin_web`** — o mesmo raciocínio da seção 2.

## 7. Impersonação (suporte entrando numa academia)

Não implementado hoje. Desenho proposto:

### Como funciona

1. `SYSTEM_ADMIN`, na tela de detalhe de uma academia (System Admin), aciona "Entrar como suporte".
2. Backend (`POST /admin/academias/:id/impersonar`, `SystemAdminGuard`) emite um **access token novo**, de vida curta (proposta: 15min — mesmo teto do access token normal, não mais que isso), com o `academiaId` da academia-alvo e o `role` do `ACADEMIA_ADMIN` daquela academia — mas **sem gerar refresh token novo**. Sessão de impersonação não é renovável silenciosamente: expirou, o `SYSTEM_ADMIN` pede de novo, deliberadamente (menos conveniente, mais seguro — mesma classe de trade-off já aceita para o access token normal em `docs/11-security.md`).
3. O JWT emitido carrega um claim adicional, `impersonatedBy: <id do SYSTEM_ADMIN>` — nunca presente num token de login normal. Toda ação feita durante a sessão de impersonação passa por esse token, então `AuditService.record()` (que já lê o usuário autenticado do `TenantContext`) grava esse claim em todo `AuditLog` criado durante a sessão. Isso é o que garante que uma ação feita durante suporte nunca fica indistinguível de uma ação real do dono da academia.
4. O frontend do `admin_web` (não o System Admin — a sessão de impersonação **roda dentro do produto SaaSGym**, porque é lá que o suporte precisa agir) exibe uma faixa fixa e inconfundível: "Você está em modo suporte, atuando como *[nome da academia]* — sair". Isso não é opcional nem discreto: existe precisamente para que quem está impersonando nunca esqueça que não é sua própria conta.
5. "Sair" (ou a expiração dos 15min) encerra a sessão — auditado (`IMPERSONATION_ENDED`), sem revogar nada da conta real do `ACADEMIA_ADMIN` (a impersonação nunca gera nem consome refresh tokens da conta impersonada).

### O que a impersonação explicitamente não faz

- Não usa (nem jamais lê) a senha do `ACADEMIA_ADMIN` — o `SYSTEM_ADMIN` nunca sabe nem precisa saber a senha de ninguém.
- Não é acionável sobre uma academia sem `ACADEMIA_ADMIN` ativo (não há identidade para assumir).
- Não estende automaticamente — sem refresh, sem "lembrar por 7 dias".
- Não fica silenciosa no frontend — a faixa da seção 4 acima é obrigatória, não uma preferência de UX.

### O que fica pendente de decisão (fora deste documento)

Se ações destrutivas específicas (ex.: cancelar a própria matrícula de um aluno, excluir a academia) devem ser bloqueadas mesmo sob impersonação, ou se o log de auditoria robusto já é suficiente controle. Marcado como decisão a tomar na sprint que implementar isso, não aqui.

## 8. Estrutura de módulos do System Admin

**Frontend (`system_admin_web/`, novo)**:
- Login (mesma tela conceitual do `admin_web`, mesmo endpoint — só aceita `SYSTEM_ADMIN`; login de qualquer outro role nesse app deve ser rejeitado na UI mesmo sabendo que o backend já rejeitaria via guard, para dar um erro claro em vez de uma tela vazia).
- Academias — lista/detalhe/criação/edição/transição de status (já existe no backend, tela nova).
- Planos SaaS — catálogo comercial (já existe no backend, tela nova).
- Dashboard da plataforma — agregados já existentes (`GET /admin/dashboard`) + o que fizer sentido conforme o produto cresce.
- Impersonação — ação a partir do detalhe de uma academia (seção 7), com histórico de sessões.
- Auditoria — visualizar `AuditLog` sem o filtro de tenant (hoje só existe consumo de auditoria implícito, sem tela; primeira tela dedicada).
- (Futuro, não deste documento) Solicitações de trial pendentes (seção 6), billing, gestão de usuários de suporte.

**Backend (`backend/src/modules/admin/`, já existe, cresce por sub-pasta)**:
- `academias/` — já existe.
- `planos-saas/` — já existe.
- `dashboard/` — já existe.
- `impersonacao/` — novo, quando implementado.
- `auditoria/` — novo, quando implementado (hoje `AuditService.record()` só grava; não há endpoint de leitura cross-tenant).

## 9. Regras de segurança

- **`SystemAdminGuard` é a fronteira real, não a UI.** Um item de menu ausente no `admin_web` é conveniência, não segurança — o que impede um `ACADEMIA_ADMIN` de acessar qualquer rota do System Admin é o guard checando `role === SYSTEM_ADMIN` no backend, mesmo que ele descubra a URL. Isso já é verdade hoje (`docs/12-multi-tenant.md`) — este documento não muda o mecanismo, só reforça que o novo frontend não pode ser a única defesa.
- **Autenticação compartilhada, sessões nunca misturadas.** Mesmo `POST /api/auth/login`, mesmo `User`, mesmo JWT — mas um usuário só tem um `role`, nunca os dois. Não existe (nem deve existir) uma conta que seja `ACADEMIA_ADMIN` de uma academia **e** `SYSTEM_ADMIN` ao mesmo tempo.
- **CORS**: `CORS_ORIGINS` (`docs/11-security.md`) precisa incluir a origem do novo app quando ele existir (dev: nova porta local, ex. `5002`; produção: subdomínio próprio, ex. `admin-plataforma.saasgym.com`, distinto do subdomínio usado por `admin_web`). Sem essa origem na lista, o navegador bloqueia — reforça (não substitui) o isolamento de guard.
- **Impersonação é o maior risco novo introduzido por este documento** — mitigado pelo desenho da seção 7 (token de vida curta, sem refresh, auditoria com `impersonatedBy`, indicação visual obrigatória). Nenhuma outra funcionalidade do System Admin aumenta a superfície de risco além do que `admin`/`SystemAdminGuard` já expõem hoje.
- **Rate limiting/Helmet/`AllExceptionsFilter` continuam globais** (`docs/11-security.md`) — cobrem o System Admin automaticamente por já serem `APP_GUARD`/`APP_FILTER` no `AppModule`, sem configuração adicional.
- **Papel de suporte futuro** (seção 1): quando existir, deve ser um novo valor de `Role` (ex.: `SUPORTE`) com um subconjunto dos endpoints hoje restritos a `SYSTEM_ADMIN` — nunca um `SYSTEM_ADMIN` "fraco" nem uma flag booleana solta no `User`. É uma migration futura, fora do escopo deste documento.

## 10. Impactos na arquitetura atual

O que muda de fato, e o que fica exatamente como está:

- **Muda**: monorepo ganha um terceiro app Flutter Web (`system_admin_web/`), irmão de `admin_web`/`student_web`. Nenhum dos dois apps existentes é alterado por isso.
- **Muda**: `CORS_ORIGINS` precisa incluir a origem do app novo, quando ele for implementado.
- **Muda (futuro, não agora)**: `backend/src/modules/admin/` ganha sub-pastas novas (`impersonacao/`, `auditoria/`), e o enum `AuditAction` ganha valores novos (`IMPERSONATION_STARTED`/`IMPERSONATION_ENDED`) — migrations e código de uma sprint futura, não deste documento.
- **Não muda**: backend continua um único NestJS (monolito modular) — sem novo serviço, sem novo banco, sem duplicar `TenantContext`/`PrismaService.forTenant()`/`AuditService`.
- **Não muda**: `admin_web`/`student_web` — nenhuma tela, rota ou item de sidebar novo neles. O System Admin nunca aparece lá.
- **Não muda**: mecanismo de autenticação (`docs/03-fluxo-autenticacao.md`, `docs/10-auth.md`) — mesmo login, mesmos guards, mesma estratégia de access/refresh token. A única adição conceitual (token de impersonação, seção 7) é um novo *uso* do mecanismo existente, não um mecanismo novo.
- **Não muda**: `packages/shared_core` continua existindo como está; o novo app **consome** dele (cliente HTTP, sessão de auth, tokens de design), sem exigir nenhuma mudança nos arquivos que `admin_web`/`student_web` já usam.

## Próximos passos (fora deste documento)

Este documento não abre nenhuma sprint. Quando o dono do produto decidir seguir, a ordem natural (seguindo `docs/08-roadmap.md`, um passo de cada vez, conforme `docs/06-modulo-...` de análise prévios): (1) esqueleto do `system_admin_web` + login, (2) telas de Academias/Planos SaaS/Dashboard consumindo os endpoints já existentes, (3) impersonação, (4) auditoria cross-tenant. Aprovação de trial (seção 6) só entra em algum ponto dessa sequência se/quando auto-signup for decidido — não está pressuposto.
