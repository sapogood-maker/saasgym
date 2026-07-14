# Módulo 3 — Financeiro: análise de domínio (pré-implementação)

Escrito ao final da Sprint de Consolidação do Módulo 2 (Matrículas), antes de qualquer código do Módulo 3, seguindo o mesmo fluxo usado em `docs/16-modulo-2-matriculas-analise.md`: analisar → propor → aprovar → só então implementar — aplicado ao modelo de domínio, não a uma tela.

Financeiro é o módulo que faz o ERP "fechar a conta": até aqui o sistema sabe *quem* está matriculado e *quanto* deveria pagar (`Matricula.valor`/`diaVencimento`), mas não existe nenhum registro de cobrança nem de recebimento. Nenhuma decisão aqui está implementada ainda.

## O papel do Financeiro no ERP

- **Cobrança**: transforma o contrato (`Matricula`) em cobranças concretas e datadas (`Mensalidade`).
- **Caixa**: registra entradas/saídas que não vêm de mensalidade (`Lancamento`) — ex. venda de produto avulso, conta de luz.
- **Negócio**: é o módulo que responde "quanto a academia faturou", "quem está inadimplente", "qual o fluxo de caixa do mês" — o critério de valor já registrado em `docs/16`/[[feedback_academia_facing_value]] se aplica com ainda mais força aqui, porque é literalmente sobre dinheiro.
- **Fora do escopo deste módulo** (confirmado no roadmap, `docs/08-roadmap.md`, seção "Decisões em aberto"): gateway de pagamento real (Mercado Pago/Asaas) para o aluno pagar pelo portal — isso é Sprint/Módulo 10 (Portal do Aluno). Módulo 3 é **gestão administrativa** da cobrança (a recepção/admin registra manualmente que recebeu), não processamento de pagamento online.

## Decisões de modelo propostas

### 1. `Mensalidade` não guarda status "atrasada" — é sempre calculado

Alternativa descartada: um enum `PENDENTE | PAGA | ATRASADA | CANCELADA` com um job que vira `PENDENTE` em `ATRASADA` quando passa do vencimento. Isso exigiria infraestrutura de scheduler que **não existe no projeto hoje** (nenhum `@nestjs/schedule`/cron configurado) só para manter um campo derivável. Proposta: `status` guarda só `PENDENTE | PAGA | CANCELADA`; "atrasada" é `status == PENDENTE && dataVencimento < hoje`, calculado na query/response — mesmo princípio já usado no projeto de preferir campo computado a estado redundante que precisa de sincronização ativa (nenhum enum novo "só para cache de uma comparação de data").

### 2. Geração de `Mensalidade`: manual (sob demanda), não por cron — nesta fase

Sem scheduler no projeto, três formas de gerar a cobrança mensal existem: (a) job automático rodando todo dia gerando o que vence naquele mês; (b) geração antecipada de todas as mensalidades da vigência no momento da criação/renovação da `Matricula`; (c) botão manual ("Gerar mensalidades do mês") que o `ACADEMIA_ADMIN`/`RECEPCIONISTA` aciona. Proposta: **(c) manual nesta fase** — introduzir um scheduler é uma peça de infraestrutura nova (mesmo critério já aplicado a `AppAutocompleteField`/`CrudRepository`: não construir até existir necessidade real confirmada), e geração antecipada (b) trava valor/desconto de meses futuros antes da hora (não acomoda desconto pontual, aumento de mensalidade por decisão da academia, etc.). **Isto é uma decisão de negócio — ver seção final.**

### 3. `Mensalidade` é sempre mensal, independente da periodicidade do `Plano`

Um `Plano` `TRIMESTRAL`/`SEMESTRAL`/`ANUAL` define a **vigência da matrícula** (`docs/16`), não a cadência de cobrança. Proposta: toda `Mensalidade` cobre exatamente 1 mês, mesmo dentro de uma `Matricula` trimestral — ou seja, uma matrícula trimestral gera 3 `Mensalidade`s ao longo da vigência, não 1 cobrança única de valor triplicado. `valor` de cada `Mensalidade` é `Matricula.valor` (o valor mensal já acordado), não dividido nem multiplicado. **Alternativa a confirmar**: alguns planos trimestrais/anuais são pagos à vista (1 cobrança cobrindo o período todo) — se esse for um caso real da academia, a cadência precisa ser um dado por `Plano` (`cadenciaCobranca: MENSAL | INTEGRAL`), não assumida fixa. **Isto é uma decisão de negócio — ver seção final.**

### 4. `Lancamento` é a entidade "guarda-chuva"; `Mensalidade` é um caso específico de receita

Proposta: `Lancamento` (receita/despesa manual, ex. venda de produto, conta de luz, salário) é **independente** de `Mensalidade` — não são a mesma tabela com um discriminador. Quando uma `Mensalidade` é marcada como paga, o sistema cria um `Lancamento` do tipo `RECEITA` automaticamente ligado a ela (`lancamento.mensalidadeId`), para que "fluxo de caixa do mês" seja sempre `SELECT SUM(valor) FROM lancamentos WHERE tipo = ...` sem precisar fazer `UNION` com a tabela de mensalidades. Evita "god table" (mesmo princípio já em `docs/02-banco-de-dados.md`, "Princípios de modelagem").

### 5. `formaPagamento` fica em `Lancamento` (não em `Mensalidade`)

`Mensalidade` sabe que foi paga (`dataPagamento`) e quanto (`valor` líquido de desconto/multa); *como* foi paga (dinheiro/PIX/cartão/boleto) é um dado do recebimento em si, que já mora em `Lancamento` (item 4) — evita duplicar o campo nas duas tabelas. Novo enum `FormaPagamento` (`DINHEIRO | PIX | CARTAO_CREDITO | CARTAO_DEBITO | BOLETO | OUTRO`).

### 6. `desconto`/`multa` como campos próprios em `Mensalidade`, `valor` permanece o valor de tabela

Já reservado desde `docs/16` (item 6): `Mensalidade.valor` = `Matricula.valor` no momento da geração (snapshot, mesmo princípio de `Matricula.valor` vs `Plano.valor`); `desconto`/`multa` (`Decimal`, default `0`) ajustam pra cima/baixo só naquela cobrança específica. `valorFinal` (`valor - desconto + multa`) é **computado na resposta**, não armazenado — mesmo princípio do item 1 (evitar redundância que pode dessincronizar).

### 7. Cancelamento de `Mensalidade` existe, mas é distinto de "Cancelar Matrícula"

Uma `Mensalidade` pode precisar ser cancelada isoladamente (cobrança gerada por engano, aluno trancou depois de gerada) sem cancelar a matrícula inteira. Proposta: `status = CANCELADA` na própria `Mensalidade`, motivo em texto livre (sem categorização — ainda não há um 2º caso de uso real pedindo relatório agrupado sobre isso, diferente de `MotivoCancelamento` de Matrícula que já tinha motivação clara de relatório de churn).

### 8. `Lancamento.categoria` — texto livre nesta fase, não catálogo

Uma entidade `CategoriaLancamento` cadastrável (com cor, tipo) seria mais rica para relatório, mas é a 1ª ocorrência de categorização financeira no produto — mesmo critério já usado pra não criar `AppCurrencyField`/`Modalidade` antes da hora. Proposta: `categoria String?` livre nesta fase (ex. "Aluguel", "Produtos", "Salário"); vira catálogo só se um caso real (filtro/relatório por categoria) pedir.

## Rascunho de schema (Prisma) — para validação, não para aplicar ainda

```prisma
enum MensalidadeStatus {
  PENDENTE
  PAGA
  CANCELADA
}

enum FormaPagamento {
  DINHEIRO
  PIX
  CARTAO_CREDITO
  CARTAO_DEBITO
  BOLETO
  OUTRO
}

enum LancamentoTipo {
  RECEITA
  DESPESA
}

model Mensalidade {
  id         String   @id @default(uuid())
  academiaId String
  academia   Academia @relation(fields: [academiaId], references: [id], onDelete: Cascade)

  matriculaId String
  matricula   Matricula @relation(fields: [matriculaId], references: [id])

  alunoId String // denormalizado pra query direta, mesmo padrão de Matricula.createdByUserId
  aluno   Aluno  @relation(fields: [alunoId], references: [id])

  valor    Decimal @db.Decimal(10, 2) // snapshot de Matricula.valor na geração
  desconto Decimal @default(0) @db.Decimal(10, 2)
  multa    Decimal @default(0) @db.Decimal(10, 2)

  dataVencimento DateTime
  dataPagamento  DateTime?

  status MensalidadeStatus @default(PENDENTE)
  motivoCancelamento String? // só quando status = CANCELADA

  createdByUserId String
  createdByUser   User   @relation(fields: [createdByUserId], references: [id])

  deletedAt DateTime?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  lancamento Lancamento? // criado quando marcada como paga — item 4

  @@index([academiaId])
  @@index([matriculaId])
  @@index([alunoId])
  @@map("mensalidades")
}

model Lancamento {
  id         String   @id @default(uuid())
  academiaId String
  academia   Academia @relation(fields: [academiaId], references: [id], onDelete: Cascade)

  tipo           LancamentoTipo
  descricao      String
  categoria      String?
  valor          Decimal        @db.Decimal(10, 2)
  data           DateTime
  formaPagamento FormaPagamento?

  mensalidadeId String?      @unique
  mensalidade   Mensalidade? @relation(fields: [mensalidadeId], references: [id])

  createdByUserId String
  createdByUser   User   @relation(fields: [createdByUserId], references: [id])

  deletedAt DateTime?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([academiaId])
  @@index([mensalidadeId])
  @@map("lancamentos")
}
```

Novas ações de `AuditAction`: `MENSALIDADE_GERADA`, `MENSALIDADE_PAGA`, `MENSALIDADE_CANCELADA`, `LANCAMENTO_CREATED`, `LANCAMENTO_UPDATED`, `LANCAMENTO_DELETED` — mesmo padrão de Matrícula/Plano.

## Fora do escopo do Módulo 3 (deliberado, não esquecido)

- Gateway de pagamento real / cobrança online pelo portal do aluno — Sprint/Módulo 10 (Portal do Aluno), conforme já registrado em `docs/08-roadmap.md`.
- Geração automática de `Mensalidade` via scheduler — manual nesta fase (item 2); reavaliar quando/se o projeto introduzir infraestrutura de cron por outro motivo.
- Catálogo de categorias de lançamento — texto livre nesta fase (item 8).
- Nota fiscal / emissão fiscal.
- Enforcement dos limites de `PlanoSaas` (`limiteAlunos` etc.) — o roadmap nota que a partir daqui existem dados suficientes para isso (`docs/13-admin-saas.md`), mas é uma feature do painel `SYSTEM_ADMIN`, não do Financeiro da academia. **Confirmar se entra neste módulo ou fica para depois — ver seção final.**

## Decisões de negócio confirmadas pelo dono do produto (2026-07-12)

1. **Geração de Mensalidade**: manual, sob demanda (botão "Gerar mensalidades do mês") — confirma o item 2 como está. Sem scheduler nesta fase.
2. **Cadência de cobrança**: sempre mensal, independente da periodicidade do `Plano` — confirma o item 3 como está. `Plano` não ganha campo de cadência de cobrança.
3. **Enforcement de limites de `PlanoSaas`**: fica de fora do Módulo 3 — é feature do painel `SYSTEM_ADMIN` (fase pausada), não do Financeiro da academia.

O modelo proposto na seção "Rascunho de schema" acima está validado e pronto para ir a plano de implementação (MS1 do Módulo 3 — schema + migration + services + endpoints + auditoria + testes).

## Plano de micro-sprints (proposto, mesma cadência do Módulo 2)

- **MS1 — Backend**: schema (`Mensalidade`, `Lancamento`, enums), migration, `MensalidadesService` (gerar do mês, listar, marcar paga, cancelar), `LancamentosService` (CRUD completo), endpoints, auditoria, testes unit + e2e.
- **MS2 — Camada de dados (frontend)**: `Mensalidade`/`Lancamento` em `shared_core`, `MensalidadesApi`/`LancamentosApi` (estende `CrudApi<T>` onde couber, métodos próprios pra gerar/marcar paga/cancelar — mesmo critério já usado em `MatriculasApi`), providers.
- **MS3 — Lista de Mensalidades**: `AppListToolbar`+`AppListTile`+`AppPagination` (mesmo padrão consolidado), com o botão "Gerar mensalidades do mês" e ações rápidas (marcar paga/cancelar).
- **MS4 — Caixa**: ver seção "MS4 — Lançamento é cadastro ou Livro Caixa?" abaixo (substitui a formulação original "Lançamentos: lista + formulário").
- **MS5 — Painel Financeiro Gerencial**: ver seção "MS5 — Fluxo de Caixa ou Painel Financeiro Gerencial?" abaixo (substitui a formulação original "Fluxo de caixa", pra não confundir com o Caixa do MS4).

## MS4 — Lançamento é cadastro ou Livro Caixa?

Análise feita antes de iniciar o MS4, a pedido do dono do produto — mesmo fluxo analisar → propor → aprovar → implementar já usado para o modelo de domínio inteiro deste módulo.

**Quais lançamentos nascem automaticamente**: todo `Lancamento` `RECEITA` vinculado a uma `Mensalidade` paga (`MensalidadesService.marcarPaga`, `descricao: "Mensalidade — {aluno.nome}"`) — numa academia com N alunos ativos, até N lançamentos por mês nascem só de marcar mensalidades como pagas na tela do MS3, sem nenhuma ação de "criar lançamento". Já protegidos contra edição/remoção direta (`garantirNaoGeradoPorMensalidade`).

**Quais precisam ser manuais**: só dois casos — despesas (aluguel, luz, salário, manutenção) e receitas avulsas (venda de produto, diária, personal avulso). Volume pequeno perto do que já chega pronto via Mensalidade.

**Lançamentos ou Caixa**: `Lancamento` não tem estado por linha (diferente de Mensalidade — pendente/paga/cancelada, ou de Aluno/Professor/Plano — ciclo de vida completo). O que importa aqui é a **soma**, não o registro isolado; o dono da academia pensa em "quanto entrou, quanto saiu, qual o saldo do mês", não em "abrir o cadastro de Lançamentos e editar o registro #4521". `LancamentosService.list` já filtra por `tipo`/`dataInicio`/`dataFim` e ordena por `data desc` — já é, na prática, um livro-razão; só falta o saldo, que ainda não existe em lugar nenhum do backend.

**Conclusão**: MS4 é um **Livro Caixa por competência** (mesmo eixo mês/ano de Mensalidades), não uma lista genérica de cadastro:
- Saldo do período em destaque no topo (entradas − saídas do mês selecionado — **não** acumulado desde o início; visão histórica/multi-mês fica pro MS5).
- Lista cronológica do mês, incluindo os lançamentos gerados por Mensalidade (só-leitura, marca visual de "gerado automaticamente") lado a lado com os manuais.
- Ação rápida "Novo lançamento" (receita/despesa) em diálogo — mesmo padrão de `_AcoesMensalidadeDialog`, sem tela de Detalhe própria (não há necessidade: nenhuma linha tem ciclo de vida a exibir).
- Editar/Remover só nos lançamentos manuais (guarda já existe no backend).
- **Decisão confirmada**: a data de um lançamento manual **não** fica restrita ao mês/ano em foco na tela — o filtro de competência é só uma lente de visualização; o usuário pode lançar uma despesa atrasada de outro mês e ela aparece ao navegar até lá.
- Exige uma peça de backend nova: endpoint de **resumo do período** (`totalReceitas`/`totalDespesas`/`saldo`) — somar client-side só a página atual da lista paginada daria conta errada.

## MS5 — Fluxo de Caixa ou Painel Financeiro Gerencial?

Análise feita antes de iniciar o MS5, a pedido do dono do produto — mesmo fluxo analisar → propor → aprovar → implementar.

**O que o Caixa (MS4) já resolve**: saldo do mês, receitas, despesas, lista cronológica de lançamentos — ferramenta **operacional/transacional** ("o que entrou e saiu, deixa eu lançar uma despesa"). Se o MS5 fosse "mais um Fluxo de Caixa", seria redundante.

**O que falta — rotina real do dono da academia**: ele não abre um painel financeiro todo dia; confere semanal/mensalmente pra responder perguntas que nenhuma tela atual responde: *"estou indo bem esse mês comparado aos anteriores?"*, *"quanto eu deveria estar recebendo vs quanto recebi de fato?"*, *"quanto tenho parado, atrasado, sem receber?"*. Isso é análise gerencial, não lançamento de transação.

**Indicador por indicador**:
- **Despesas**/**Saldo**: já existem no Caixa (`LancamentosService.resumo`) — reuso direto.
- **Receita recebida**: parcial — Caixa já soma `Lancamento` tipo RECEITA do mês; ganha sentido novo ao lado da prevista.
- **Receita prevista**: não existe em lugar nenhum — soma de `Matricula.valor` das matrículas ATIVA cuja vigência cobre o mês, **independente de "Gerar mensalidades" já ter rodado** (o dono deve poder ver isso antes de clicar em Gerar).
- **Inadimplência**: não existe como agregado, só como badge por linha em Mensalidades — soma/contagem de `Mensalidade` PENDENTE com vencimento no passado.
- **Evolução mensal**: não existe — série de meses recentes (receita recebida/despesas/saldo).

Receita prevista + recebida juntas viram um indicador derivado de alto valor — **taxa de recebimento** (`recebido / previsto`) — mais útil pra decisão do que os totais isolados.

**Conclusão**: **Painel Financeiro Gerencial**, não Fluxo de Caixa — confirma e refina o que este documento já cogitava na primeira versão ("painel/dashboard financeiro").

**Decisões de negócio confirmadas pelo dono do produto (2026-07-13)**:
1. **Inadimplência é tempo real, sempre total** — soma/conta todas as `Mensalidade` PENDENTE vencidas até hoje, independente do mês selecionado no painel (não escopada à competência em foco, diferente dos outros 4 indicadores) — reflete a dívida real da academia agora, mais útil pra cobrança do que uma foto histórica de um mês específico.
2. **Evolução mensal é lista/tabela compacta, não gráfico** — sem biblioteca de gráficos nem componente de chart novo (nenhum existe hoje no Design System nem como dependência do projeto); uma lista dos últimos meses com Receita/Despesa/Saldo, reaproveitando `AppCard`/`AppListTile`. Evolui pra gráfico de verdade só se um caso real pedir (mesmo critério já usado em `AppAutocompleteField`/scheduler).

**Novas peças de backend necessárias**:
- `MensalidadesService.receitaPrevista(mes, ano)` — soma de `Matricula.valor` das ATIVA cuja vigência cobre o mês (mesma query de matrículas elegíveis já usada em `gerar`, sem criar registros).
- `MensalidadesService.inadimplencia()` — soma/contagem de `Mensalidade` PENDENTE com `dataVencimento < hoje`, sem parâmetro de mês/ano (é sempre "agora").
- `LancamentosService.evolucao(meses)` — array dos últimos N meses (`resumo` por mês, mesma lógica de agregação já existente).

## Histórico

- **2026-07-12**: primeira versão — análise de domínio antes de qualquer implementação do Módulo 3, ao final da Sprint de Consolidação do Módulo 2.
- **2026-07-12**: as 3 decisões de negócio em aberto foram confirmadas pelo dono do produto, todas seguindo a opção recomendada. Modelo de domínio considerado fechado para o MVP do Módulo 3. Plano de micro-sprints proposto, aguardando aprovação para iniciar o MS1.
- **2026-07-12, MS1**: schema (`Mensalidade`/`Lancamento` + enums `MensalidadeStatus`/`FormaPagamento`/`LancamentoTipo`), migration, `MensalidadesService`/`LancamentosService`, endpoints REST, auditoria e testes (177 e2e + 110 unit no total do backend). Achado real durante a implementação: `TENANT_SCOPED_MODELS` (`prisma-tenant.extension.ts`) precisou registrar `Mensalidade`/`Lancamento` — passo já previsto no comentário da própria extensão desde o Sprint 1, não uma surpresa de arquitetura. Módulos Nest organizados como `financeiro/mensalidades/` e `financeiro/lancamentos/` sob um único `FinanceiroModule` agregador, mesmo padrão de `AdminModule` (`admin/academias/`, `admin/dashboard/`, `admin/planos-saas/`). Acesso restrito a `ACADEMIA_ADMIN`/`RECEPCIONISTA` — sem `PROFESSOR` (diferente de Planos/Matrículas), por ser dado financeiro da academia.
- **2026-07-12, MS2**: camada de dados frontend — `Mensalidade`/`Lancamento` em `shared_core`, `MensalidadesApi`/`LancamentosApi`, providers. Princípio de auditabilidade financeira registrado em `docs/15` antes da implementação (toda mutação financeira já grava `auditService.record`, confirmado contra o código do MS1 — nenhuma mudança de backend precisou ser feita, o princípio já estava sendo seguido).
- **2026-07-13, MS3**: Lista de Mensalidades (`MensalidadesScreen`). Decisão de análise pré-implementação, confirmada: a tela é orientada por **competência (mês/ano)**, não por busca — `MensalidadesService.gerar(mes, ano)` não existe sem um mês selecionado, então a tela carrega por padrão só o mês corrente (diferente de todas as telas anteriores, que carregam "tudo"); busca por aluno e filtro de status continuam dentro do `AppListToolbar` de sempre, como complemento. `Mensalidade.atrasada` (computado, nunca armazenado) virou tom de badge (`AppBadgeTone.error`), não uma nova dimensão de filtro — evita parâmetro sem necessidade comprovada. Ajuste pontual descoberto durante o MS3: `search` adicionado a `ListMensalidadesQueryDto`/`MensalidadesService.list` (contains case-insensitive em `aluno.nome`), mesmo padrão já usado em Matrículas MS3. Sem tela de Detalhe própria para Mensalidade neste módulo — as 4 ações (marcar como paga, editar, cancelar, remover) vivem em `_AcoesMensalidadeDialog`, mesmo padrão de diálogo-próprio-com-chassi-de-`AppConfirmDialog` já registrado em `docs/15` para `_CancelarMatriculaDialog` (Matrículas MS5). Nenhum componente novo do Design System. Validação manual via Playwright confirmou as 4 ações de ponta a ponta contra o backend real (incluindo o `Lancamento` criado automaticamente ao marcar como paga, e o bloqueio de "Remover" para mensalidade `PAGA`), além dos 5 estados obrigatórios e responsividade mobile.
- **2026-07-13, pré-MS4**: análise de domínio — "Lançamento é cadastro ou Livro Caixa?" (seção acima). Conclusão: Livro Caixa por competência, não lista genérica. Confirmado pelo dono do produto: saldo é do período selecionado (não acumulado — visão histórica fica pro MS5); data de lançamento manual não é restrita ao mês em foco na tela (filtro de competência é só lente de visualização). MS4 reformulado de "Lançamentos: lista + formulário" para "Caixa" — exige endpoint novo de resumo do período (`totalReceitas`/`totalDespesas`/`saldo`), aguardando aprovação do plano de implementação para iniciar.
- **2026-07-13, MS4**: `CaixaScreen`. Dois ajustes pedidos antes de implementar, ambos aplicados: (1) resumo do período (`GET /financeiro/lancamentos/resumo`) retorna também `quantidadeReceitas`/`quantidadeDespesas`, não só os totais financeiros; (2) novo campo `origem` (`LancamentoOrigem`: `MANUAL | MENSALIDADE`) em `Lancamento` — passa a ser o campo autoritativo pra decidir editável/removível, substituindo a heurística anterior baseada em `mensalidadeId != null` (guarda em `LancamentosService` atualizada; dados existentes migrados via backfill SQL). Resposta de `Lancamento` enriquecida com `alunoNome`/`mensalidadeDataVencimento` (só quando `origem = MENSALIDADE`) — permite a linha do Caixa navegar direto até a Mensalidade correspondente (competência + busca por aluno), já que este módulo não tem tela de Detalhe própria pra Mensalidade; `MensalidadesScreen` ganhou parâmetros iniciais opcionais (`initialMes`/`initialAno`/`initialBusca`, lidos da query string da rota) pra essa navegação cruzada funcionar sem duplicar lógica. `intervaloDoMes` extraído de `mensalidades.util.ts` para um novo `financeiro.util.ts` compartilhado (2º consumidor real — `LancamentosService.list`/`resumo` — mesmo gatilho de extração já usado em outras decisões deste documento). Sidebar dividida em duas entradas ("Mensalidades" e "Caixa") em vez de um único item "Financeiro" — mesma convenção de nomear pela entidade, não por um termo guarda-chuva. Nenhum componente novo do Design System — `MetricCard` (já previsto desde o Dashboard) cobre o resumo financeiro; `_AcoesLancamentoDialog` reusa o chassi de `_AcoesMensalidadeDialog`/`_CancelarMatriculaDialog`. Achado de teste (não é bug de produto): `AppSelect` reabre a lista de opções alinhando o item **selecionado** com a posição do campo (não sempre o item 0 no topo) — relevante pra quem for automatizar cliques nesse componente.
- **2026-07-13, pré-MS5**: análise de domínio — "Fluxo de Caixa ou Painel Financeiro Gerencial?" (seção acima). Conclusão: Painel Financeiro Gerencial — receita prevista, receita recebida, inadimplência, despesas, saldo e evolução mensal, não mais um livro-caixa (isso já é o MS4). Confirmado pelo dono do produto: inadimplência é tempo real/sempre total (não escopada à competência do painel, diferente dos outros indicadores); evolução mensal é lista/tabela compacta dos últimos meses, sem gráfico nem biblioteca de chart nesta fase (nenhuma existe hoje no projeto). MS5 renomeado de "Fluxo de caixa" para "Painel Financeiro Gerencial" — exige 3 peças novas de backend (`receitaPrevista`, `inadimplencia`, `evolucao`), aguardando aprovação do plano de implementação para iniciar.
- **2026-07-13, MS5**: `PainelFinanceiroScreen`, encerrando o Módulo 3. Quatro ajustes pedidos antes de implementar, todos aplicados: (1) `evolucao` retorna `receitaPrevista` por mês, além de recebida/despesas/saldo; (2) taxa de recebimento (`recebida / prevista`) calculada no frontend (`ResumoFinanceiro.taxaRecebimento`/`EvolucaoMensalItem.taxaRecebimento`, getters — `null` sem receita prevista, nunca uma porcentagem inventada), nunca no backend; (3) endpoint agregador criado — `DashboardFinanceiroService`/`DashboardFinanceiroController` (`GET /financeiro/dashboard`, `GET /financeiro/dashboard/evolucao`) orquestram `MensalidadesService`/`LancamentosService` via injeção direta, zero regra de negócio duplicada; (4) sem gráfico — `_EvolucaoTabela` é uma tabela composta com `AppCard`+`Row`+`Divider` no desktop e cards empilhados no mobile, nenhum componente novo do Design System. Peças novas no backend: `MensalidadesService.receitaPrevista`/`.inadimplencia` (métodos de serviço, sem endpoint HTTP próprio — só consumidos pelo orquestrador, evita expor superfície de API sem consumidor real) e `financeiro.util.ts#mesRecuado` (janela de meses com virada de ano, 2º uso de `Date.UTC` com overflow proposital, mesmo padrão de `dataVencimentoNoMes`). `receitaPrevista` reaproveita a mesma query de elegibilidade de matrículas já usada em `MensalidadesService.gerar` — funciona mesmo antes de "Gerar mensalidades do mês" ter rodado. Sidebar "Financeiro" agora com 3 entradas (Mensalidades/Caixa/Painel). Validação manual confirmou a decisão de inadimplência tempo-real na prática: o card não muda de valor ao trocar a competência do painel (mesmo R$150,00 em Julho/2026 e Agosto/2025), diferente dos outros 4 indicadores.
