# Sprint 6 — Agenda Avançada: análise de domínio (pré-implementação)

Escrito antes de qualquer código, seguindo o mesmo fluxo de `docs/16`/`docs/17`/`docs/18`/`docs/20`: analisar → propor → aprovar → só então implementar. Este módulo não introduz nenhuma entidade do zero — reaproveita deliberadamente o que já foi modelado desde o Módulo 4 MS1 e nunca usado: `AulaAluno.tipo = REPOSICAO`, `AulaAluno.reposicaoDeAulaAlunoId` e `AuditAction.AULA_ALUNO_REPOSICAO_CRIADA` existem no schema há um módulo inteiro, sem nenhum código que os escreva.

## O que já estava decidido antes desta sprint (docs/18, não reaberto aqui)

- **Reposição não é uma entidade com vida própria** — é `AulaAluno.tipo = REPOSICAO` + `reposicaoDeAulaAlunoId` (auto-relacionamento apontando pro `AulaAluno` original substituído). Confirmado, mantido.
- **`SolicitacaoAgenda`** (o nome usado em `docs/02`/`docs/18` para esse conceito) foi explicitamente adiada "até existir o Portal do Aluno" — porque um pedido do próprio aluno exige o aluno ter login. Isso **muda nesta sprint**: como não existe portal ainda (`student_web` continua sendo só o esqueleto do Sprint 0), a solicitação nasce sempre pela **recepção**, registrando o que o aluno pediu por telefone/presencialmente — não uma auto-solicitação. Ver decisão 1.
- **Fila de espera** (`AulaAluno.tipo = FILA_ESPERA`) **não está no escopo desta sprint** — o pedido do dono do produto lista só "reposição", não fila de espera. Continua sem implementação, junto de `Enforcement de Plano.quantidadeAulas` e `AgendaPessoalProfessor`.
- **`NotificationProvider`** — a interface nunca foi escrita; só existia a intenção registrada (`docs/08`, "Decisões em aberto": "a integração deve seguir o mesmo padrão de abstração usado em `StorageProvider`").

## Decisões de modelo propostas

### 1. `SolicitacaoReposicao` — nome restrito ao escopo real, não o `SolicitacaoAgenda` genérico cogitado antes

`docs/02`/`docs/18` cogitavam um `SolicitacaoAgenda` mais amplo ("troca de horário pelo portal do aluno"). O pedido desta sprint é só reposição, sempre registrada pela recepção — proponho `SolicitacaoReposicao`, nome que reflete exatamente o que existe, sem prometer um conceito mais genérico ainda não pedido. Se um dia existir "troca de horário" como um pedido distinto, é uma entidade nova a avaliar então, não uma generalização antecipada desta.

### 2. Toda solicitação nasce de um `AulaAluno` existente — nunca "solta"

`aulaAlunoOrigemId` é obrigatório: representa o vínculo aluno↔aula que está sendo substituído (uma aula que o aluno perdeu — por falta ou por cancelamento). Sem isso, "reposição de quê?" fica sem resposta. **Restrição proposta**: só é possível abrir uma solicitação se essa `Aula` de origem já **passou** (mesmo cálculo de "realizada" usado desde o MS7/MS8: `data < hoje`) **e** ou (a) `Aula.status == CANCELADA`, ou (b) `AulaAluno.presenca` é `AUSENTE`/`JUSTIFICADA`. Não faz sentido pedir reposição de uma aula futura, nem de uma aula em que o aluno esteve `PRESENTE`.

### 3. ~~Solicitação já nasce com a aula de destino escolhida~~ — **revisado**: destino só é escolhido na aprovação

**Decisão confirmada pelo dono do produto (2026-07-14), substituindo a proposta original desta seção**: a solicitação registra só que o aluno pediu reposição de uma aula perdida — `aulaDestinoId` **não existe até a aprovação**. A recepção escolhe a aula de destino no momento de decidir, não na criação. `aulaDestinoId` é `nullable`, preenchido exclusivamente pela própria operação de aprovação (nunca por um `update` isolado da solicitação). Antes de aprovar, o sistema recalcula a capacidade da aula escolhida em tempo real (decisão 5). Destino deve ser uma `Aula` futura (`data >= hoje`) com `status = AGENDADA`.

### 4. Aprovação/rejeição — sem distinção de papel entre quem cria e quem decide

O sistema não tem hoje um papel "supervisor" distinto de `RECEPCIONISTA`/`ACADEMIA_ADMIN` (`Role` só tem `SYSTEM_ADMIN`/`ACADEMIA_ADMIN`/`RECEPCIONISTA`/`PROFESSOR`/`ALUNO`). Proposta: qualquer `ACADEMIA_ADMIN`/`RECEPCIONISTA` pode criar **e** decidir uma solicitação — inclusive a mesma pessoa que criou. O "fluxo de aprovação" existe como **estado** (`PENDENTE → APROVADA | REJEITADA`), não como controle de dois papéis diferentes. **Decisão a confirmar — não crio um novo papel/permissão pra isso sem pedido explícito.**

### 5. Aprovar é a única forma de criar o `AulaAluno(tipo=REPOSICAO)` — sem atalho direto

Diferente do fluxo descrito em `docs/18` ("recepção cria o `AulaAluno` de reposição diretamente"), esta sprint substitui esse atalho pelo fluxo completo pedido: **não existe mais criação direta** de reposição — toda reposição nasce de uma `SolicitacaoReposicao` aprovada. Aprovar, dentro de uma `$transaction` (mesmo padrão de `MensalidadesService.marcarPaga`/`AdminAcademiaService.updateStatus`), faz duas coisas atomicamente: (a) recontagem de capacidade da `Aula` de destino (mesma mitigação de concorrência já prevista em `docs/18`, seção 6, nunca implementada até agora); (b) cria o `AulaAluno(tipo=REPOSICAO, aulaId=destino, alunoId=<mesmo aluno>, reposicaoDeAulaAlunoId=origem)`. Se a aula de destino já estiver cheia no momento da aprovação, a aprovação falha (409) — a solicitação continua `PENDENTE`, a recepção escolhe outro destino e tenta de novo.

### 6. Reabertura após rejeição — validado no service, nunca constraint de banco

Uma solicitação `REJEITADA` não impede uma nova solicitação para o mesmo `aulaAlunoOrigemId` depois (o aluno pode pedir de novo com outro destino). A regra "no máximo uma solicitação `PENDENTE`/`APROVADA` ativa por origem" é validada no service (mesmo padrão de `garantirSemInscricaoAtiva` do `TurmaAluno`) — **não** uma `@@unique` de banco na FK sozinha, exatamente a lição já aprendida com o bug real do `TurmaAluno` no Módulo 4 MS5 (constraint que bloqueava reinscrição depois de sair).

### 7. `NotificationProvider` — mesmo desenho de `StorageProvider`, um único canal concreto por enquanto

Interface pura + token de injeção (`NOTIFICATION_PROVIDER`, mesmo padrão de `STORAGE_PROVIDER`) — nenhum módulo de negócio importa uma implementação concreta diretamente. Única implementação nesta fase: `InternalNotificationProvider`, que persiste em `Notificacao` (nova tabela) — sem e-mail/WhatsApp/push reais. Diferente de `StorageProvider` (um provider ativo por vez, trocável), notificação por natureza pode um dia sair por **múltiplos canais ao mesmo tempo** (interno + e-mail) — mas isso só vira um problema de desenho quando existir um 2º canal de verdade; nesta fase, um único provider ativo é suficiente e não fecho porta nenhuma (a interface não assume "canal único" em lugar nenhum do contrato).

### 8. Notificação é sempre dirigida a um `User` específico — nunca "toda a academia"

`Notificacao.userId` obrigatório. Quando um evento precisa avisar várias pessoas (ex.: nova solicitação pendente deveria avisar toda a recepção), o **chamador** faz o fan-out (uma `Notificacao` por destinatário elegível), a interface do provider continua simples (um destinatário por chamada) — sem inventar o conceito de "notificação de grupo" no schema antes de existir necessidade real de consultá-la dessa forma.

### 9. Quando notificar (2 eventos, ambos dentro do escopo desta sprint)

- **Ao criar uma `SolicitacaoReposicao`** (`PENDENTE`): notifica todos os `User` da academia com role `ACADEMIA_ADMIN`/`RECEPCIONISTA`, exceto quem criou (já sabe).
- **Ao decidir** (`APROVADA`/`REJEITADA`): notifica especificamente quem **criou** a solicitação (é quem precisa repassar a resposta pro aluno, por telefone/presencialmente).

### 10. Notificação nunca é fato auditado (`AuditLog`)

`AuditLog` registra ações de negócio com efeito sobre dados (criar/aprovar/rejeitar a solicitação, por exemplo); o envio de uma notificação é um efeito colateral dessas ações, não uma ação em si — marcar uma notificação como lida também não gera auditoria (equivalente a "ler" um registro, nunca auditado em nenhum outro lugar do sistema).

### 11. Frontend: nova tela de topo "Reposições", não embutida

Diferente de Recorrência/TurmaAluno/Aulas (sempre dentro do contexto de uma Turma já aberta), uma solicitação de reposição é criada a partir do histórico de frequência de **um aluno**, mas a **gestão** (ver pendentes, aprovar, rejeitar) precisa de uma visão cruzando todos os alunos/turmas da academia — mesmo raciocínio que já justificou `CalendarScreen` como tela de topo no MS7. Ação "Solicitar reposição" fica acessível a partir de `AlunoDetailScreen` (seção Frequência, que hoje é só um placeholder — ver observação abaixo) ou da própria tela de Reposições ("Nova solicitação", escolhendo o aluno).

### 12. Sino de notificações do `AppHeader` passa a mostrar dado real

Hoje `_NotificationsButton` abre um popover fixo "EM DESENVOLVIMENTO" (`_showComingSoonPopover`, achado durante a Sprint de Consolidação). Esta sprint substitui esse conteúdo por uma lista real das notificações do usuário logado (não lidas em destaque, contador no ícone, marcar como lida) — reaproveitando o mesmo mecanismo de popover a partir do ícone, sem componente novo do Design System.

## Rascunho de schema (Prisma) — para validação, não para aplicar ainda

```prisma
enum SolicitacaoReposicaoStatus {
  PENDENTE
  APROVADA
  REJEITADA
}

model SolicitacaoReposicao {
  id         String   @id @default(uuid())
  academiaId String
  academia   Academia @relation(fields: [academiaId], references: [id], onDelete: Cascade)

  alunoId String
  aluno   Aluno  @relation(fields: [alunoId], references: [id])

  aulaAlunoOrigemId String
  aulaAlunoOrigem   AulaAluno @relation("SolicitacaoReposicaoOrigem", fields: [aulaAlunoOrigemId], references: [id])

  // Nulo até a aprovação (decisão 3, confirmada) — a recepção escolhe o
  // destino no momento de decidir, nunca na criação da solicitação.
  aulaDestinoId String?
  aulaDestino   Aula?  @relation("SolicitacaoReposicaoDestino", fields: [aulaDestinoId], references: [id])

  // Preenchido só quando aprovada — o AulaAluno(tipo=REPOSICAO) criado.
  aulaAlunoReposicaoId String?    @unique
  aulaAlunoReposicao   AulaAluno? @relation("SolicitacaoReposicaoResultado", fields: [aulaAlunoReposicaoId], references: [id])

  status         SolicitacaoReposicaoStatus @default(PENDENTE)
  observacoes    String?
  motivoRejeicao String?

  createdByUserId String
  createdByUser   User   @relation("SolicitacoesReposicaoCriadas", fields: [createdByUserId], references: [id])

  decidedByUserId String?
  decidedByUser   User?     @relation("SolicitacoesReposicaoDecididas", fields: [decidedByUserId], references: [id])
  decidedAt       DateTime?

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([academiaId, alunoId])
  @@index([academiaId, status])
  @@map("solicitacoes_reposicao")
}

model Notificacao {
  id         String   @id @default(uuid())
  academiaId String
  academia   Academia @relation(fields: [academiaId], references: [id], onDelete: Cascade)

  userId String
  user   User   @relation(fields: [userId], references: [id])

  titulo   String
  mensagem String

  lida   Boolean   @default(false)
  lidaEm DateTime?

  createdAt DateTime @default(now())

  @@index([academiaId, userId, lida])
  @@map("notificacoes")
}
```

Novos `AuditAction`: `SOLICITACAO_REPOSICAO_CRIADA`, `SOLICITACAO_REPOSICAO_APROVADA`, `SOLICITACAO_REPOSICAO_REJEITADA`. `AULA_ALUNO_REPOSICAO_CRIADA` já existe desde o MS1 do Módulo 4 e é usado pela primeira vez, gravado junto da aprovação.

`Aluno`/`Aula`/`AulaAluno`/`User`/`Academia` ganham as relações opostas correspondentes, mesmo padrão de todo o schema.

## Fluxo operacional completo

1. Aluno falta numa aula (ou a aula é cancelada) — `AulaAluno.presenca = AUSENTE`/`JUSTIFICADA`, ou `Aula.status = CANCELADA`.
2. Aluno liga/aparece pedindo reposição. Recepção abre "Nova solicitação" (a partir da Frequência do aluno ou da tela de Reposições) e escolhe só a aula de origem (perdida) — **sem escolher destino ainda** (decisão 3, confirmada).
3. Sistema cria `SolicitacaoReposicao(status=PENDENTE, aulaDestinoId=null)` e notifica os demais `ACADEMIA_ADMIN`/`RECEPCIONISTA` da academia.
4. Alguém da recepção (a mesma pessoa ou outra) revisa a lista de pendentes e decide:
   - **Aprovar**: recepção escolhe a aula de destino **neste momento**; recontagem de capacidade dessa aula dentro de uma transação; se houver vaga, cria `AulaAluno(tipo=REPOSICAO, reposicaoDeAulaAlunoId=origem)`, grava `aulaDestinoId`, marca a solicitação `APROVADA`, audita `SOLICITACAO_REPOSICAO_APROVADA` + `AULA_ALUNO_REPOSICAO_CRIADA`, notifica quem criou. Se a aula escolhida estiver cheia, a aprovação falha (409) e a recepção escolhe outra.
   - **Rejeitar**: marca `REJEITADA` com motivo opcional, audita `SOLICITACAO_REPOSICAO_REJEITADA`, notifica quem criou. Nenhum `AulaAluno` é criado.
5. A reposição aprovada aparece na aula de destino como qualquer outro `AulaAluno` — conta pra capacidade, pode ter presença marcada normalmente quando a aula de destino acontecer (mesmo fluxo de Frequência do MS8, sem nenhuma mudança nele).

## Riscos e integrações

- **Concorrência de capacidade na aprovação** — mesma mitigação já prevista (e nunca aplicada) em `docs/18`: recontagem dentro de `$transaction` antes de criar o `AulaAluno`, não apenas checar-e-inserir.
- **Integração com Frequência (MS8)**: a origem da solicitação é sempre um `AulaAluno` já existente com presença marcada como falta (ou aula cancelada) — nenhuma mudança no fluxo de marcar presença em si; só uma nova leitura sobre dado que já existe.
- **Integração com Agenda (MS6/MS7)**: a aula de destino segue exatamente as mesmas regras de qualquer `AulaAluno` novo (deve estar `AGENDADA`, no futuro, dentro da capacidade) — nenhuma mudança no gerador de aulas nem no calendário.
- **Nenhuma regressão**: nenhuma tabela/endpoint/tela existente é alterada por esta sprint além do conteúdo do sino de notificações (que hoje é só um placeholder estático, sem nenhum consumidor real dependendo do texto "EM DESENVOLVIMENTO").

## Fora do escopo desta sprint (deliberado)

- Fila de espera (`AulaAluno.tipo = FILA_ESPERA`) e sua promoção — não pedida nesta sprint.
- Canais reais de notificação (e-mail, WhatsApp, push) — só a abstração, como explicitamente pedido.
- "Troca de horário" livre (sem estar ligada a uma aula perdida) — o pedido desta sprint é só reposição.
- Qualquer coisa vinda do Portal do Aluno (auto-solicitação pelo próprio aluno) — continua exigindo o Módulo 10.
- Enforcement de `Plano.quantidadeAulas` — mencionado em `docs/18`, ainda não implementado, não pedido aqui.

## Plano de micro-sprints (proposto)

- **MS1 — Backend: Solicitação de Reposição.** Schema (`SolicitacaoReposicao`, migration), service/controller (criar, listar/filtrar por status, editar enquanto `PENDENTE`, aprovar, rejeitar), validações (origem elegível, destino válido, capacidade recontada em transação, no máximo uma solicitação ativa por origem), auditoria, testes e2e completos.
- **MS2 — Backend: Notificações internas.** `NotificationProvider`/`NOTIFICATION_PROVIDER` + `InternalNotificationProvider`, `Notificacao` (schema, migration), endpoints (listar minhas notificações, marcar como lida), integração com o MS1 (os 2 eventos da seção "Quando notificar"), testes.
- **MS3 — Shared Core.** Models (`SolicitacaoReposicao`, `Notificacao`) + APIs bespoke (nenhuma estende `CrudApi<T>` — convenção já fechada na Sprint de Consolidação) + providers.
- **MS4 — Frontend.** Tela de topo "Reposições" (lista/filtro por status, aprovar/rejeitar), ação "Solicitar reposição" a partir da Frequência do aluno, sino de notificações real no `AppHeader`. Validação manual via Playwright, galeria de screenshots.

Cada MS: `flutter analyze` limpo, testes completos, documentação atualizada, validação manual — mesmo padrão de todos os módulos anteriores.

## Decisões confirmadas pelo dono do produto (2026-07-14)

1. **Aprovar/rejeitar** (decisão 4) — confirmado: qualquer `ACADEMIA_ADMIN`/`RECEPCIONISTA` pode decidir, sem papel de "supervisor" distinto.
2. **Origem da reposição** (decisão 2) — confirmado: só aula com falta (`AUSENTE`/`JUSTIFICADA`) ou cancelada; nunca aula com presença, futura ou ainda não realizada.
3. **Fluxo da solicitação** (decisão 3) — **revisado em relação à proposta original**: a solicitação NÃO exige aula de destino na criação — só registra o pedido do aluno sobre a aula perdida. A recepção escolhe o destino durante a aprovação, com recontagem de capacidade em tempo real naquele momento (não na criação). Ver schema/fluxo atualizados acima.
4. **Criação da reposição** (decisão 5) — confirmado: `AulaAluno(tipo=REPOSICAO)` só nasce durante a aprovação; nenhum atalho direto.
5. **Tela** (decisão 11) — confirmado: tela própria "Reposições" dentro do módulo Agenda (não embutida em Turma/Aluno).

**Diretrizes adicionais confirmadas**: auditoria em toda mudança de estado; `$transaction` em qualquer alteração de múltiplas entidades (aprovação escreve `SolicitacaoReposicao` + `AulaAluno` atomicamente); `NotificationProvider` nasce desacoplado (suporta múltiplos canais futuros — interno/e-mail/WhatsApp/push — mas só o canal interno é implementado nesta sprint); nenhum componente novo do Design System sem necessidade comprovada; documentação, testes e isolamento multi-tenant no mesmo padrão de todos os módulos anteriores.

## Histórico

- **2026-07-14, MS1 (Backend — Solicitações de Reposição)**: `SolicitacaoReposicao` implementada exatamente como confirmado (schema com `aulaDestinoId` nulo até a aprovação). Migration `20260714134943_sprint6_solicitacao_reposicao` (novo model + enum `SolicitacaoReposicaoStatus` + `AuditAction.SOLICITACAO_REPOSICAO_CRIADA/APROVADA/REJEITADA`). `SolicitacaoReposicao` entrou em `TENANT_SCOPED_MODELS`. Novo submódulo `agenda/solicitacoes-reposicao` (controller de topo, `agenda/solicitacoes-reposicao`, registrado em `AgendaModule` — mesma organização de arquivo que `aulas-calendario`): `criar` (valida origem elegível — aula já realizada + cancelada ou com falta — e ausência de solicitação ativa pra mesma origem), `list` (paginado, filtro por status/aluno, ordenado por criação desc), `aprovar` (recebe `aulaDestinoId` só agora, recontagem de capacidade + criação do `AulaAluno(tipo=REPOSICAO)` + atualização da solicitação, tudo numa `$transaction`), `rejeitar` (motivo opcional). Achado real durante a implementação, não previsto na análise: `AulaAluno` já tinha `@@unique([aulaId, alunoId])` desde o Módulo 4 MS1 — aprovar uma reposição pra uma aula onde o aluno já está vinculado (matriculado normalmente, por exemplo) violaria essa constraint; adicionada uma checagem explícita (`jaVinculado`) que bloqueia com 400 antes de chegar na transação, em vez de deixar o erro estourar como uma falha de banco genérica. `@Roles(ACADEMIA_ADMIN, RECEPCIONISTA)` nos 4 endpoints (sem `PROFESSOR` — diferente de Avaliação Física, aqui não foi pedido). 18 testes e2e novos (criar com falta/cancelada, bloqueios de origem — presente/sem presença/futura —, 404 de origem, 409 de solicitação ativa duplicada, aprovar com sucesso criando o `AulaAluno` de verdade, 409 de capacidade cheia sem alterar a solicitação, bloqueios de destino — cancelado/passado/aluno já vinculado —, bloqueio de decidir solicitação já decidida, rejeitar liberando nova solicitação pra mesma origem, listagem filtrada/ordenada, isolamento de tenant) — 126 unit + 331 e2e no total, todos verdes. `NotificationProvider`/`Notificacao` e integração de notificação ficam para o MS2, exatamente como planejado — nenhuma chamada a um provider que ainda não existe foi adicionada nesta sprint.
- **2026-07-14, MS2 (Backend — Notificações internas)**: `NotificationProvider`/`NOTIFICATION_PROVIDER` (mesmo desenho de `StorageProvider`/`STORAGE_PROVIDER`) + `InternalNotificationProvider` (único canal, persiste em `Notificacao` — nova tabela, migration `20260714141442_sprint6_notificacoes`, entrou em `TENANT_SCOPED_MODELS`). Novo módulo de topo `backend/src/notifications/` (sibling de `storage/`, não `modules/` — mirror explícito da decisão 7). `notify()` nunca propaga erro (mesmo princípio de `AuditService.record`) — uma falha ao notificar nunca derruba criar/aprovar/rejeitar uma solicitação. Lado de leitura (`NotificacoesService`/`Controller`, `GET notificacoes` + `PATCH notificacoes/:id/lida`) é deliberadamente separado da interface do provider — "listar"/"marcar como lida" só fazem sentido pro canal interno (um e-mail/WhatsApp não tem "lida" dentro do nosso sistema), então ficam fora de `NotificationProvider`. Resposta paginada já traz `naoLidas` (contagem separada) pro badge do sino — evita um filtro de `lida` em query string (nenhum precedente de `@IsBoolean`/`@Transform` de boolean em query param no projeto; mais simples ordenar não-lidas primeiro do que introduzir esse padrão novo). `SolicitacoesReposicaoService` integrado: ao criar, notifica todos `ACADEMIA_ADMIN`/`RECEPCIONISTA` ativos da academia exceto quem criou (fan-out, um `Notificacao` por destinatário); ao aprovar/rejeitar, notifica quem criou. Marcar como lida nunca gera `AuditLog` (decisão 10). 7 testes e2e novos (lista vazia, ordenação não-lidas-primeiro/mais-recentes, marcar como lida idempotente sem auditoria, bloqueio de marcar notificação de outro usuário, integração completa ponta a ponta via `POST solicitacoes-reposicao` confirmando quem recebe e quem não recebe, isolamento de tenant) — 126 unit + 338 e2e no total, todos verdes.
- **2026-07-14, MS3 (Shared Core)**: `SolicitacaoReposicao`/`SolicitacaoReposicaoStatus`/`SolicitacoesReposicaoApi` (`agenda/`, bespoke — não estende `CrudApi<T>`, mesmo critério de `AulasApi`/`AulaAlunosApi`) + `Notificacao`/`NotificacoesApi` (novo diretório `notifications/`, espelhando o top-level `backend/src/notifications/`). `NotificacoesPaginadas` é um formato próprio (não `PaginatedResult<T>`) — carrega `naoLidas` além de `items`/`total`/`page`/`pageSize`, evitando forçar o formato genérico a acomodar um campo que só essa listagem tem. `aprovar()` recebe `aulaDestinoId` como parâmetro próprio (não um DTO de update genérico), reforçando em código que a escolha do destino é um ato da aprovação, não um dado da solicitação em si. `flutter analyze` limpo em `shared_core` e `admin_web` (dependente); 27 + 12 testes inalterados e verdes.
- **2026-07-14, MS4 (Frontend — admin_web) — encerra a Sprint 6**: `AppIcons.reposicao` (`LucideIcons.repeat`) — único acréscimo ao Design System, um token, não um componente novo. `AppHeader` ganhou `notificacoesNaoLidas`/`onNotificationsTap` (opcionais, default preserva o popover "em breve" antigo) — o sino continua sem saber nada de API/Riverpod; toda a busca de dados e composição do popover vive em `admin_web/app_shell.dart` (`_notificacoesProvider`, `FutureProvider.autoDispose`, mesmo padrão de `_dashboardProvider`/`_perfilProvider`). Nova tela de topo `ReposicoesScreen` (`/agenda/reposicoes`, entrada de sidebar logo após "Calendário") — filtro de status (`AppSelect`, default Pendente), sem `AppListToolbar` (mesmo motivo de `CalendarScreen`: não há busca por nome no backend). `CalendarScreen` ganhou o outro lado do fluxo: aula cancelada agora expõe "Ver alunos / Solicitar reposição" (reaproveita o mesmo `_abrirFrequencia()`/`_alunosFuture` de "Registrar frequência" — únicos dois caminhos que levam à mesma view de alunos); a view de Frequência ficou compartilhada entre os dois casos de uso, escondendo o seletor de presença quando a aula está cancelada e mostrando o ícone "Solicitar reposição" quando a origem é elegível (cancelada OU falta/falta justificada). `_NovaSolicitacaoReposicaoDialog` só pede observações — sem campo de destino, reforçando a decisão 3 também na UI.
  - **Validação manual (Playwright, build de produção, autenticado como `admin@academiademo.com`)**: criadas duas solicitações reais a partir da Frequência (uma de falta justificada, outra de falta simples) e processadas as duas — uma aprovada, outra rejeitada. Confirmados os 5 estados da tela (vazio, populado, filtro Aprovada, filtro Rejeitada, mais os dois diálogos) e responsividade mobile. **Achado real durante a validação, não um bug**: a primeira tentativa de aprovação foi corretamente bloqueada pelo guard `jaVinculado` (MS1) — a única aula futura disponível no ambiente de teste era a própria aula regular da aluna, na qual ela já está matriculada; escolhida uma aula extra fora da matrícula regular, a aprovação seguiu normalmente. Confirmado também o fim a fim de notificação: como o ambiente de teste tinha um único `ACADEMIA_ADMIN` (o próprio criador da solicitação), o fan-out de "nova solicitação" (que exclui quem criou) não gerou notificação visível — mas as duas notificações de decisão (aprovada/rejeitada, dirigidas a quem criou) apareceram corretamente no sino, com contagem de não lidas, conteúdo (incluindo o motivo da rejeição e a data/turma de destino da aprovação) e marcação de lida com reordenação, tudo validado. `flutter analyze` limpo, 27 + 12 testes inalterados e verdes. Dados de teste (solicitações, aulas extras, notificações) removidos após a validação.
  - Com o MS4, a **Sprint 6 (Agenda Avançada) está completa** — reposição de aulas, fluxo de aprovação/rejeição pela recepção e notificações internas integrados à Agenda e à Frequência já existentes, sem regressão nos módulos anteriores.
