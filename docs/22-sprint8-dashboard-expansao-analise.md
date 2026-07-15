# Sprint 8 — Dashboard da academia (expansão) — Análise de domínio

> **Revisão 2026-07-15**: análise original re-enquadrada a pedido do usuário. Mudança de moldura, não descarte — a maior parte do levantamento factual (APIs reaproveitáveis) continua válida. O que muda é *o que a tela é* e *como o layout se organiza*. Nenhum código foi implementado em nenhuma das duas versões; esta ainda aguarda aprovação.

## O que a tela é (reenquadramento)

A versão anterior tratava o Dashboard como "painel de indicadores com alguns cards a mais". Reenquadrado: o Dashboard é o **Centro de Operações** da academia — a tela que responde "o que eu preciso fazer agora?", não "quais são meus números?". Isso já estava implícito no comentário que existe hoje em `dashboard_screen.dart` ("a pergunta que a tela responde é 'o que eu preciso fazer hoje', não 'aqui estão meus indicadores'") — esta revisão leva essa premissa até o fim, inclusive cortando o que não serve a essa pergunta.

Consequência prática: **prioridade explícita** Agenda da Semana → Financeiro/Alertas → Navegação rápida → Indicadores (por último, como já é hoje). E **nada de gráfico** — nenhuma seção desta sprint usa série temporal, pizza ou barra. Todo dado novo aparece como número, lista curta ou link, igual ao padrão já estabelecido em "Alunos novos"/"Aniversariantes".

## O que já existe (levantamento factual, nada implementado ainda)

**Backend do dashboard hoje** (`backend/src/modules/dashboard/`): `DashboardService.get()` roda tudo em paralelo via `Promise.all`, escopado ao tenant — `totalAlunos`, `alunosAtivos`, `totalProfessores`, `novosAlunosMes`, `aniversariantes` (SQL bruto, Prisma não expressa "mês ignorando ano"), `usuariosDoSistema`, `alunosNovos` (top 5 mais recentes).

**Agenda — reaproveitável sem query nova**: `GET agenda/aulas` (`AulasService.listCalendario`) já aceita `dataInicio`/`dataFim`/`turmaId`/`professorId`/`modalidadeId`/`status` combinados, paginado (`backend/src/modules/agenda/aulas/aulas.service.ts:173`). O filtro é um intervalo de datas genérico — pedir a semana (`dataInicio = hoje`, `dataFim = hoje+6`) é o mesmo reaproveitamento que pedir só o dia, não uma query nova. Cada aula já vem com turma, professor, horário, status e `totalAlunos`.

**Financeiro — parcialmente reaproveitável**: `MensalidadesService.inadimplencia()` já calcula valor/quantidade de mensalidades vencidas em tempo real. `DashboardFinanceiroService.resumo(mes, ano)` já combina `receitaPrevista` + `receitaRecebida` + `despesas` + `saldo` + inadimplência numa única chamada — é o agregado de "faturamento do mês". **Não existe** hoje nenhuma query de "próximos vencimentos" (mensalidades a vencer nos próximos N dias) — continua sendo a única peça genuinamente nova do lado do Financeiro.

**Achado de arquitetura, não só de dado**: `DashboardModule`, `AgendaModule` e `FinanceiroModule` são três módulos Nest independentes, nenhum exporta seus services hoje. O único precedente de composição entre services de módulos diferentes é `DashboardFinanceiroService`, que evita esse problema vivendo dentro do próprio `FinanceiroModule`. Estender o dashboard geral pra ler Agenda/Financeiro é o primeiro caso do produto de um módulo precisando injetar services de dois outros módulos de negócio ao mesmo tempo — ver decisão 2.

## Decisões de modelo propostas

### 1. Escopo: "Agenda da semana" (não "do dia") + "Alertas importantes" (financeiro) + "Navegação rápida" (nova)

Trocar o recorte de "hoje" para "próximos 7 dias corridos" — mesma janela já usada para os vencimentos financeiros (decisão 3), o que dá à tela uma única noção de "semana operacional" em vez de duas janelas diferentes (dia vs. semana) coexistindo sem motivo. Justificativa de produto: "o que tenho hoje" é útil de manhã e inútil à tarde; "o que vem essa semana" continua acionável o dia inteiro e serve pra planejamento (cobertura de professor, sala cheia etc.), não só pra conferência do dia corrente.

"Ações pendentes" (matrículas) e "Últimas atividades" (auditoria) **saem do layout desta sprint** — não viram mais `EmptyState.comingSoon`. Motivo: um card "em breve" permanente é ele mesmo um widget sem função operacional (ninguém age em cima de um placeholder), o que contradita o pedido de evitar widgets desnecessários. "Ações pendentes" também continua apontando pra um conceito que não existe no domínio (`MatriculaStatus` não tem estado "pendente de confirmação") — modelar isso é decisão de domínio própria, fora desta sprint. O acesso à tela de Matrículas passa a vir da seção de Navegação rápida (decisão 7), que cumpre o mesmo papel ("preciso ver isso") sem prometer uma feature que não existe.

### 2. Agregação server-side num único `GET /dashboard` (mantida)

Duas formas de resolver: (a) o frontend dispara 3 chamadas em paralelo; ou (b) `DashboardService` importa `AgendaModule`/`FinanceiroModule` (que passam a exportar `AulasService`/`MensalidadesService`), e o próprio `GET /dashboard` já devolve os campos novos prontos.

Proposta: **(b)**, mantida da versão anterior. Mantém o padrão "uma tela, uma chamada" (`_dashboardProvider`, `FutureProvider.autoDispose`) e trata o dashboard consistentemente como um agregador. Custo: `AgendaModule`/`FinanceiroModule` ganham `exports: [AulasService]` / `exports: [DashboardFinanceiroService, MensalidadesService]` — primeira vez que exportam algo, mas não é acoplamento novo de fato (o dashboard já lê tabelas de `Aluno`/`User` diretamente hoje).

### 3. Janela de "próximos vencimentos": 7 dias corridos (mantida, agora também define a janela da Agenda)

Mensalidades com `status = PENDENTE` e `dataVencimento` entre hoje e hoje+7 (inclusive). Mesma janela agora usada pela Agenda da Semana (decisão 1) — a tela passa a ter um único conceito de "semana", não dois.

### 4. "Alertas importantes" continua uma lista curta, não só números (mantida)

Card financeiro mostra `inadimplenciaValor`/`inadimplenciaQuantidade` como resumo, mais uma lista combinada (vencidas primeiro, depois as que vencem nos próximos 7 dias, ordenadas por `dataVencimento` crescente dentro de cada grupo) com aluno + valor + vencimento + tag `vencida`/`a vencer`, capada em 10 itens. Continua sendo a seção de maior prioridade da tela — é a única com valor em R$ e ação imediata (ligar pro aluno).

### 5. "Agenda da semana" mostra a lista agrupada por dia, sem paginação

Aulas dos próximos 7 dias, agrupadas por dia (cabeçalho "Hoje", "Amanhã", depois dia da semana + data) e ordenadas por `horaInicio` dentro de cada dia — turma, professor, status. Teto de segurança de 100 itens no total (mesma lógica defensiva de `ALUNOS_NOVOS_LIMITE`, só que numa janela 7x maior). Dias sem aula não geram cabeçalho vazio — a lista simplesmente pula pro próximo dia com aula, evitando ruído visual de "sem aulas hoje" repetido.

### 6. Único método novo de verdade: `MensalidadesService.proximosVencimentos(dias: number)` (mantida)

Tudo mais reaproveita métodos já existentes (`AulasService.listCalendario`, `MensalidadesService.inadimplencia`, `DashboardFinanceiroService.resumo`). Essa é a única query nova do backend nesta sprint — nenhuma API nova é criada para a Agenda da Semana, só um intervalo de datas diferente na mesma chamada que já existia.

### 7. Navegação rápida — nova seção, 100% frontend, sem API

Grade curta de atalhos (ícone + label) para as telas mais acessadas a partir do Dashboard: Alunos, Matrículas, Financeiro (Mensalidades), Agenda/Calendário, Avaliação Física. Cada atalho é só um `context.push(rota)` para rotas que já existem no `go_router` — nenhum endpoint novo, nenhum dado do backend. Resolve o mesmo problema que os placeholders "Ações pendentes"/"Últimas atividades" tentavam resolver (dar acesso rápido a um módulo), sem prometer conteúdo que não existe.

Como componente, isso é um candidato natural a entrar no Design System como algo reutilizável (ex.: um `QuickActionTile` — ícone, label, `onTap`), já que o padrão do produto é priorizar componentes que sirvam outras telas no futuro (ex.: uma home de professor ou de recepção poderia usar o mesmo tile).

## Arquitetura para permitir reordenar/ocultar cards no futuro (proposta agora, sem implementar personalização)

Hoje `dashboard_screen.dart` é uma árvore de widgets fixa: cada seção é escrita diretamente no `Column` de `_DadosConteudo`/`DashboardScreen.build`, na ordem em que aparece no código. Pra reordenar ou ocultar uma seção no futuro, alguém precisaria editar essa árvore — não dá pra expor isso como preferência de usuário sem reescrever a tela.

Proposta de arquitetura (só a estrutura de dados e o ponto de extensão — **sem** UI de personalização, sem persistência de preferência nesta sprint):

- Cada seção passa a ser descrita por um `DashboardSectionId` (enum: `alertasFinanceiros`, `agendaSemana`, `navegacaoRapida`, `indicadores`, `alunosNovos`, `aniversariantes`) associado a um builder de widget (`Widget Function(DashboardAcademia dashboard)`).
- Uma lista ordenada `const _defaultSectionOrder = [DashboardSectionId.alertasFinanceiros, DashboardSectionId.agendaSemana, ...]` define a ordem hoje — a mesma ordem de prioridade operacional definida nesta análise.
- `DashboardScreen` renderiza via `for (final id in sectionOrder) sectionBuilder[id](dashboard)` em vez de widgets escritos em sequência no `Column`.
- Nesta sprint, `sectionOrder` é sempre `_defaultSectionOrder` (nenhuma tela de configuração, nenhum `SharedPreferences`, nenhum campo novo no backend). O ganho é só estrutural: quando a personalização for pedida, ela se resume a trocar de onde `sectionOrder` vem (constante → preferência do usuário) e, pra ocultar, filtrar a lista antes do `for` — sem tocar em nenhum builder de seção individual.

Isso é reaproveitamento de um padrão já comum em Flutter (lista de config + builder por id) — não introduz biblioteca nova nem abstração especulativa além do necessário pra não precisar reescrever a tela quando a personalização for pedida de verdade.

## Forma proposta do DTO (`DashboardAcademiaResponseDto`, campos novos)

```
aulasSemana: AulaResumoDto[]            // próximos 7 dias, reaproveita o shape de AulaResponseDto (ou subconjunto), cap 100
financeiro: {
  receitaPrevista: number               // mês corrente — DashboardFinanceiroService.resumo()
  receitaRecebida: number
  despesas: number
  saldo: number
  inadimplenciaValor: number
  inadimplenciaQuantidade: number
  mensalidadesAlerta: MensalidadeAlertaDto[]   // vencidas + próximos 7 dias, capado em 10
}
```

Os campos existentes (`totalAlunos`, `alunosAtivos`, `aniversariantes` etc.) não mudam. Renomeado de `aulasHoje` (versão anterior) para `aulasSemana` — reflete a janela de 7 dias da decisão 1.

## Fluxo operacional

1. `GET /dashboard` continua uma única chamada, `ACADEMIA_ADMIN`/`RECEPCIONISTA` (mesmos roles de hoje).
2. `DashboardService.get()` passa a rodar, em paralelo com o que já existe: `AulasService.listCalendario({ dataInicio: hoje, dataFim: hoje+6, pageSize: 100 })`, `DashboardFinanceiroService.resumo({ mes, ano } = hoje)`, `MensalidadesService.proximosVencimentos(7)` (novo), reaproveitando `inadimplencia()` (já dentro de `resumo()`).
3. Frontend: `dashboard_screen.dart` reorganiza a árvore de seções na ordem Alertas → Agenda da Semana → Navegação rápida → (Alunos novos/Aniversariantes, como hoje) → Indicadores, seguindo a arquitetura de `sectionOrder` descrita acima. "Ações pendentes" e "Últimas atividades" saem do layout (decisão 1). Sem novo provider, sem nova chamada de API — o mesmo `dashboardAsync.when(...)` que já existe.

## Riscos e integrações

- **Import cruzado de módulos Nest** (decisão 2) é inédito no produto — checar se introduz dependência circular (não deveria: `DashboardModule` passa a depender de `AgendaModule`/`FinanceiroModule`, nunca o contrário).
- **Fuso horário de "hoje"/"semana"**: mesma comparação de data já usada em toda a Agenda/Financeiro (UTC, dia inteiro) — sem regra nova, só reaproveitar o padrão existente.
- **Agrupamento por dia no frontend** (decisão 5) é lógica de apresentação pura (`groupBy` sobre a lista já ordenada) — não precisa de nada novo do backend além do intervalo de datas já ampliado.
- Nenhuma migration de schema — tudo é leitura sobre tabelas já existentes.

## Fora de escopo desta sprint (deliberado)

- "Ações pendentes" (matrículas) e "Últimas atividades" (auditoria) — removidas do layout (decisão 1), substituídas pelo acesso via Navegação rápida onde aplicável.
- Qualquer configuração de "quantos dias é o alerta de vencimento/agenda" por academia (fica fixo em 7, decisões 1 e 3) — parametrização por tenant só se pedida no futuro.
- Ação direta a partir do dashboard (ex.: marcar mensalidade como paga sem sair da tela) — o card é só visão, ação continua na tela de Mensalidades/Calendário.
- Personalização de fato (reordenar/ocultar cards pelo usuário) — só a arquitetura que permite isso é criada agora; UI, persistência e endpoint de preferência ficam para quando forem pedidos.
- Gráficos de qualquer tipo — decisão de produto explícita desta revisão, não uma omissão.

## Plano de micro-sprints (proposto)

- **MS1 — Backend.** `AgendaModule`/`FinanceiroModule` passam a exportar os services necessários; `MensalidadesService.proximosVencimentos(dias)`; `DashboardService` estendido com `aulasSemana` (intervalo de 7 dias) e `financeiro`; `DashboardAcademiaResponseDto` com os campos novos; testes e2e.
- **MS2 — Shared Core.** `DashboardAcademia` (model) espelha o DTO novo; introduz `DashboardSectionId` e a estrutura de `sectionOrder` (só o tipo/enum — sem API nova, mesmo endpoint).
- **MS3 — Frontend.** `dashboard_screen.dart` reorganizado pela arquitetura de seções: Alertas e Agenda da Semana saem de `EmptyState.comingSoon` para conteúdo real; nova seção de Navegação rápida (+ eventual `QuickActionTile` no Design System); "Ações pendentes"/"Últimas atividades" removidas do layout. Validação manual via Playwright, galeria de screenshots.

Cada MS: `flutter analyze` limpo, testes completos, documentação atualizada, validação manual — mesmo padrão de todos os módulos anteriores.

## Histórico

_(preenchido ao final de cada micro-sprint)_
