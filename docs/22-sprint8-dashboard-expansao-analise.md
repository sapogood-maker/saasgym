# Sprint 8 — Dashboard da academia (expansão) — Análise de domínio

## O papel desta sprint

O dashboard básico (`GET /dashboard`) existe desde o Sprint 3 e hoje só cobre o que não dependia de nenhum módulo de negócio ainda inexistente: contagem de alunos/professores, aniversariantes do mês, alunos novos. Quatro seções da tela nasceram como placeholder (`EmptyState.comingSoon`), cada uma marcada com o módulo do qual depende:

| Seção | Placeholder atual | Depende de | Nesta sprint? |
|---|---|---|---|
| Alertas importantes | "Alunos inadimplentes e mensalidades vencendo" | Financeiro (Sprint 7) | **Sim** |
| Agenda do dia | "Aulas e horários de personal de hoje" | Agenda (Sprint 5/Módulo 4, MS7) | **Sim** |
| Ações pendentes | "Matrículas pendentes de confirmação" | Matrículas | Não — ver decisão 1 |
| Últimas atividades | "Histórico de ações da equipe" | Auditoria | Não — fora do roadmap desta sprint |

O roadmap (docs/08) já define o escopo com essa mesma granularidade: *"agenda do dia, faturamento, mensalidades vencidas/próximos vencimentos"*. As outras duas seções não aparecem nessa frase — tratadas como decisão 1 abaixo, não como esquecimento.

## O que já existe (levantamento factual, nada implementado ainda)

**Backend do dashboard hoje** (`backend/src/modules/dashboard/`): `DashboardService.get()` roda tudo em paralelo via `Promise.all`, escopado ao tenant — `totalAlunos`, `alunosAtivos`, `totalProfessores`, `novosAlunosMes`, `aniversariantes` (SQL bruto, Prisma não expressa "mês ignorando ano"), `usuariosDoSistema`, `alunosNovos` (top 5 mais recentes). O próprio DTO já tem o comentário *"Ainda sem Agenda/Financeiro (chegam em sprints futuros)"* — este é o momento.

**Agenda — reaproveitável sem query nova**: `GET agenda/aulas` (`AulasService.listCalendario`) já aceita `dataInicio`/`dataFim`/`turmaId`/`professorId`/`modalidadeId`/`status` combinados, paginado. Chamar com `dataInicio = dataFim = hoje` já devolve exatamente "as aulas de hoje" — turma, professor, horário, status, `totalAlunos`. Nenhuma agregação nova precisa ser escrita no lado da Agenda.

**Financeiro — parcialmente reaproveitável**: `MensalidadesService.inadimplencia()` já calcula valor/quantidade de mensalidades vencidas em tempo real (não escopado a competência — mesma regra de sempre, docs/17). `DashboardFinanceiroService.resumo(mes, ano)` já combina `receitaPrevista` + `receitaRecebida` + `despesas` + `saldo` + inadimplência numa única chamada — é literalmente o agregado de "faturamento do mês" que esta sprint precisa. **Não existe** hoje nenhuma query de "próximos vencimentos" (mensalidades a vencer nos próximos N dias) — é a única peça genuinamente nova do lado do Financeiro.

**Achado de arquitetura, não só de dado**: `DashboardModule`, `AgendaModule` e `FinanceiroModule` são três módulos Nest independentes, nenhum exporta seus services hoje (`AulasService`, `MensalidadesService`, `DashboardFinanceiroService` só são injetáveis dentro do próprio módulo). O único precedente de composição entre services de módulos diferentes é `DashboardFinanceiroService`, que evita esse problema propositalmente vivendo dentro do `FinanceiroModule`, junto do que orquestra (comentário explícito no código: *"por isso precisa estar no mesmo módulo, sem imports extras"*). Estender o dashboard geral pra ler Agenda/Financeiro é o primeiro caso do produto de um módulo precisando importar/injetar services de dois outros módulos de negócio ao mesmo tempo — ver decisão 2.

## Decisões de modelo propostas

### 1. Escopo desta sprint: só "Agenda do dia" + "Alertas importantes" (financeiro)

"Ações pendentes" (matrículas) aponta pra um conceito que **não existe** no domínio hoje — `MatriculaStatus` é só `ATIVA | TRANCADA | CANCELADA | ENCERRADA`, sem nenhum estado de "pendente de confirmação". Modelar isso exigiria decisão de domínio própria sobre o ciclo de vida de Matrícula (fora do que o roadmap descreve pra esta sprint). "Últimas atividades" (auditoria) não aparece na frase do roadmap e também não foi pedida. Proposta: as duas seções continuam `EmptyState.comingSoon` — só o texto/`sprintTag` são revisados se necessário (ex.: apontar pra uma sprint futura ainda sem número), sem tocar em domínio novo.

### 2. Agregação server-side num único `GET /dashboard` (não múltiplas chamadas do frontend)

Duas formas de resolver: (a) o frontend passa a disparar 3 chamadas em paralelo (`dashboardApiProvider` + `aulasApiProvider.listCalendario` + um novo endpoint financeiro), compondo tudo em `dashboard_screen.dart`; ou (b) `DashboardService` importa `AgendaModule`/`FinanceiroModule` (que passam a exportar `AulasService`/`MensalidadesService`), e o próprio `GET /dashboard` já devolve os campos novos prontos, como faz hoje com aniversariantes/alunos novos.

Proposta: **(b)**. Mantém o padrão já estabelecido de "uma tela, uma chamada" (`_dashboardProvider`, `FutureProvider.autoDispose`, sem mudança nenhuma do lado do Riverpod) e trata o dashboard consistentemente como um agregador — a mesma razão de ser de `DashboardFinanceiroService`, agora um nível acima. O custo é `AgendaModule`/`FinanceiroModule` ganharem `exports: [AulasService]`/`exports: [DashboardFinanceiroService, MensalidadesService]` — primeira vez que esses módulos exportam algo, mas não é um acoplamento novo de fato (o dashboard já lê tabelas de `Aluno`/`User` diretamente hoje; ler via service em vez de repetir a query é mais correto, não menos).

### 3. Janela de "próximos vencimentos": 7 dias corridos

Não há nenhuma decisão prévia registrada sobre esse número. Proposta: mensalidades com `status = PENDENTE` e `dataVencimento` entre hoje e hoje+7 dias (inclusive) — janela curta o bastante pra ser acionável ("vence essa semana"), sem virar uma segunda listagem completa de mensalidades dentro do dashboard.

### 4. "Alertas importantes" vira uma lista curta, não só números

Mesmo padrão já usado em "Alunos novos" (card com contagem no badge + lista dos 5 mais recentes): o card financeiro mostra `inadimplenciaValor`/`inadimplenciaQuantidade` como resumo, mais uma lista combinada (vencidas primeiro, depois as que vencem nos próximos 7 dias, ordenadas por `dataVencimento` crescente dentro de cada grupo) com aluno + valor + vencimento + uma tag indicando `vencida` ou `a vencer` — capada em 10 itens. Justificativa: só o número não é acionável pra recepção; ela precisa saber *quem* ligar.

### 5. "Agenda do dia" mostra a lista, sem paginação

Aulas de hoje ordenadas por `horaInicio`, com turma/professor/status — cru, sem cap artificial baixo (um dia de aulas raramente passa de 20-30 até em academias grandes), mas com um teto de segurança de 50 (mesma lógica defensiva de outros limites do produto, ex. `ALUNOS_NOVOS_LIMITE`) pra nunca estourar o card em um cenário extremo. Sem contador redundante — o tamanho da própria lista já comunica "quantas aulas hoje".

### 6. Único método novo de verdade: `MensalidadesService.proximosVencimentos(dias: number)`

Tudo mais reaproveita métodos já existentes (`AulasService.listCalendario`, `MensalidadesService.inadimplencia`, `DashboardFinanceiroService.resumo`). Essa é a única query nova do backend nesta sprint.

## Forma proposta do DTO (`DashboardAcademiaResponseDto`, campos novos)

```
aulasHoje: AulaResumoDto[]              // reaproveita o shape já existente de AulaResponseDto (ou um subconjunto)
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

Os campos existentes (`totalAlunos`, `alunosAtivos`, `aniversariantes` etc.) não mudam.

## Fluxo operacional

1. `GET /dashboard` continua uma única chamada, `ACADEMIA_ADMIN`/`RECEPCIONISTA` (mesmos roles de hoje).
2. `DashboardService.get()` passa a rodar, em paralelo com o que já existe: `AulasService.listCalendario({ dataInicio: hoje, dataFim: hoje, pageSize: 50 })`, `DashboardFinanceiroService.resumo({ mes, ano } = hoje)`, `MensalidadesService.proximosVencimentos(7)` (novo), e reaproveita `inadimplencia()` (já dentro de `resumo()`).
3. Frontend: `dashboard_screen.dart` substitui os 2 placeholders ("Alertas importantes", "Agenda do dia") por conteúdo real vindo do mesmo `dashboardAsync.when(...)` que já existe — sem novo provider, sem nova chamada de API.

## Riscos e integrações

- **Import cruzado de módulos Nest** (decisão 2) é inédito no produto — checar se introduz dependência circular (não deveria: `DashboardModule` passa a depender de `AgendaModule`/`FinanceiroModule`, nunca o contrário).
- **Fuso horário de "hoje"**: mesma comparação de data já usada em toda a Agenda/Financeiro (UTC, dia inteiro) — sem regra nova, só reaproveitar o padrão existente.
- Nenhuma migration de schema — tudo é leitura sobre tabelas já existentes.

## Fora de escopo desta sprint (deliberado)

- "Ações pendentes" (matrículas) e "Últimas atividades" (auditoria) — ver decisão 1.
- Qualquer configuração de "quantos dias é o alerta de vencimento" por academia (fica fixo em 7, decisão 3) — parametrização por tenant só se pedida no futuro.
- Ação direta a partir do dashboard (ex.: marcar mensalidade como paga sem sair da tela) — o card é só visão, ação continua na tela de Mensalidades/Calendário.

## Plano de micro-sprints (proposto)

- **MS1 — Backend.** `AgendaModule`/`FinanceiroModule` passam a exportar os services necessários; `MensalidadesService.proximosVencimentos(dias)`; `DashboardService` estendido com os 2 agregados novos; `DashboardAcademiaResponseDto` com os campos novos; testes e2e.
- **MS2 — Shared Core.** `DashboardAcademia` (model) espelha o DTO novo — sem API nova (mesmo endpoint).
- **MS3 — Frontend.** `dashboard_screen.dart`: "Alertas importantes" e "Agenda do dia" saem de `EmptyState.comingSoon` para conteúdo real. Validação manual via Playwright, galeria de screenshots.

Cada MS: `flutter analyze` limpo, testes completos, documentação atualizada, validação manual — mesmo padrão de todos os módulos anteriores.

## Histórico

_(preenchido ao final de cada micro-sprint)_
