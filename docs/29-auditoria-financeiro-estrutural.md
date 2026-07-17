# Auditoria Estrutural — Planos, Matrículas, Mensalidades, Renovação e Financeiro

Auditoria pré-implementação, 2026-07-17 — pedida antes de qualquer cliente real usar o sistema. **Nenhum código foi alterado.** Todo achado abaixo foi verificado lendo o código/schema atual (`prisma/schema.prisma`, `PlanosService`, `MatriculasService`, `MensalidadesService`, `DashboardFinanceiroService`), não inferido — cada afirmação cita o arquivo/trecho correspondente. Também revisitei `docs/16-modulo-2-matriculas-analise.md` e `docs/17-modulo-3-financeiro-analise.md` (as análises de domínio originais) porque vários comportamentos que parecem "falha" são, na verdade, decisões deliberadas já aprovadas — o objetivo deste documento é separar os dois, não redescobrir o que já foi decidido conscientemente.

## Resumo executivo

De 10 regras de negócio esperadas, **4 já estão corretas hoje** (Plano como modelo/matrícula como contrato, no que diz respeito a `valor`; imutabilidade de `planoId`; histórico financeiro imutável; renovação nunca sobrescreve). **2 têm um gap concreto e de risco real pra produção** (geração de mensalidade 100% manual, sem rede de segurança contra esquecimento; exclusão/edição de Plano sem guard contra matrícula vinculada). **1 é uma decisão de produto ainda não tomada** (snapshot de `nome`/`periodicidade` do Plano na Matrícula — hoje é só parcial). As demais são refinamentos.

O achado mais sério, novo e não-óbvio desta auditoria: **`renovar()` recalcula a duração da nova vigência lendo a `periodicidade` *atual* do Plano, não a que valia quando o aluno assinou** — um Plano que muda de `MENSAL` para `ANUAL` depois que um aluno já está matriculado muda silenciosamente a duração da *próxima renovação* desse aluno, sem qualquer confirmação. Ver seção 3, risco R2.

---

## 1. Fluxo atual

### 1.1 Plano

`backend/src/modules/planos/planos.service.ts`. CRUD simples: `create`/`update`/`updateStatus`/`remove`, todos sem nenhuma verificação de matrícula vinculada.

- `update()` (linha 79-100): `plano.update({ where: { id }, data: dto })` — `UpdatePlanoDto` aceita `nome`, `descricao`, `periodicidade`, `valor`, `quantidadeAulas`, `ordem`, todos opcionais, **sem nenhum guard**.
- `remove()` (linha 126-139): soft delete (`deletedAt: new Date()`) — **sem checar se existe `Matricula` vinculada**.
- `updateStatus()` (linha 102-124): já existe e já funciona — `PATCH /planos/:id/status` ativa/inativa (`UserStatus.ATIVO`/`INATIVO`). Este é o mecanismo de "inativar" que a Regra 4 do pedido já quer usar — **já implementado, só não é a alternativa oferecida hoje quando alguém tenta remover**.

### 1.2 Matrícula

`backend/src/modules/matriculas/matriculas.service.ts`.

**Criação (`create()`, linha 64-121)**: copia **só** `valor` (`dto.valor ?? plano.valor`) e `diaVencimento` (`dto.diaVencimento ?? dataInicio.getUTCDate()`) para a `Matricula`. `dataFimPrevista` é calculada uma vez (`somarPeriodicidade(dataInicio, plano.periodicidade)`) e nunca mais recalculada para esta linha. `planoId` fica como FK — **nome e periodicidade não são copiados como colunas**, continuam só acessíveis via `plano.nome`/`plano.periodicidade` (join).

**Leitura (`toResponse()`)**: `planoNome: matricula.plano.nome` — lido **ao vivo**, via `include: { plano: { select: { nome: true } } }` (linha 36-39), toda vez que uma matrícula é listada/exibida. Não existe coluna `planoNome` na tabela.

**Edição (`update()`, linha 161-183)**: só `valor`/`diaVencimento` (`UpdateMatriculaDto` deliberadamente não tem `planoId`, comentário no próprio DTO cita docs/16 item 12). Bloqueado em estado terminal (`garantirNaoTerminal`).

**Renovação (`renovar()`, linha 292-362)**: busca o Plano atual (`plano.findFirst({ where: { id: atual.planoId, deletedAt: null } })`), calcula `dataFimPrevista = somarPeriodicidade(dataInicio, plano.periodicidade)` — **usando a periodicidade do Plano *agora*, não a que a matrícula anterior usou**. `valor: dto.valor ?? Number(atual.valor)` — aqui, ao contrário, o **valor** por padrão herda da matrícula anterior, não do Plano ao vivo. Cria uma nova linha (`matriculaAnteriorId` aponta pra anterior), marca a anterior como `ENCERRADA`. **Não cria nenhuma `Mensalidade`** — a nova vigência nasce sem nenhuma cobrança gerada.

### 1.3 Mensalidade

`backend/src/modules/financeiro/mensalidades/mensalidades.service.ts`.

**Geração (`gerar()`, linha 55-118)**: `POST /financeiro/mensalidades/gerar`, **acionado manualmente** pelo `ACADEMIA_ADMIN`/`RECEPCIONISTA` (botão "Gerar mensalidades do mês" em `mensalidades_screen.dart`). Recebe `mes`/`ano` (default: mês corrente), busca todas as `Matricula` `ATIVA` cuja vigência (`dataInicio`/`dataFim`) cobre aquele mês, e para cada uma verifica se já existe `Mensalidade` pro período (`findFirst` antes de `create`, idempotente por checagem de aplicação — **sem constraint de banco**). `Mensalidade.valor` é sempre `matricula.valor` — **nunca lê `Plano.valor`**.

**Não existe scheduler.** Nenhum `@nestjs/schedule`, nenhum cron, nenhuma outra forma de gerar `Mensalidade` além desse botão manual. Confirmado em `docs/17`, item 2: "manual (sob demanda), não por cron — **nesta fase**" — decisão de produto já tomada em 2026-07-12, não um esquecimento, mas explicitamente provisória ("reavaliar quando/se o projeto introduzir infraestrutura de cron por outro motivo").

### 1.4 Dashboard / Painel Financeiro

`DashboardFinanceiroService`/`DashboardService` — **já são só leitura**, confirmando que a Regra 8 do pedido já está atendida nesse aspecto: nenhum dos dois dashboards escreve no banco. `receitaPrevista()` inclusive funciona **independente** de "Gerar mensalidades" já ter rodado (soma `Matricula.valor` das `ATIVA` elegíveis, não depende de `Mensalidade` existir) — bom desenho, mas também mascara o problema: o dono da academia pode ver "Receita Prevista: R$ 3.000" no painel e não perceber que zero `Mensalidade` foi de fato gerada/cobrada aquele mês, porque o indicador que mostraria isso (Receita Recebida) só cai visivelmente se ele souber comparar os dois números.

---

## 2. Problemas encontrados

| # | Problema | Onde | Severidade |
|---|---|---|---|
| P1 | `Plano.update()` sem guard — `valor`/`periodicidade`/`nome`/`quantidadeAulas` editáveis mesmo com matrícula vinculada | `planos.service.ts:79-100` | Média (ver seção 3, R1/R2) |
| P2 | `Plano.remove()` sem guard — soft delete não verifica matrícula vinculada | `planos.service.ts:126-139` | Alta (ver seção 3, R3) |
| P3 | `Matricula` não copia `nome`/`periodicidade` do Plano — só `valor`/`diaVencimento` são snapshot | `matriculas.service.ts:88-104` | Média (ver seção 3, R2) |
| P4 | Geração de `Mensalidade` 100% manual, sem scheduler nem lembrete — depende de alguém clicar todo mês, para sempre, por academia | `mensalidades.service.ts:55-118` | **Alta** (ver seção 3, R4) |
| P5 | Renovação não gera `Mensalidade` automaticamente — mesmo problema de P4, mas mais silencioso (a matrícula nova "existe" sem nenhum sinal visual de que falta gerar cobrança) | `matriculas.service.ts:292-362` | **Alta** (ver seção 3, R4) |
| P6 | Checagem de duplicidade em `gerar()` é em nível de aplicação (`findFirst` + `create`, fora de transação, dentro de loop sequencial), sem constraint de banco | `mensalidades.service.ts:80-91` | Baixa |
| P7 | `Plano.quantidadeAulas` não é lido por nenhuma regra de negócio hoje — puramente informativo | grep confirmou zero uso fora de DTOs/comentário análogo em `turma-alunos.service.ts` | Baixa |

---

## 3. Riscos para produção

**R1 — Editar `Plano.valor` com matrícula vinculada.** Verificado: **não afeta nada retroativamente hoje**. `Mensalidade.valor` sempre vem de `Matricula.valor` (snapshot na criação), nunca de `Plano.valor` — mesmo gerando mensalidades novas para uma matrícula antiga, o valor usado é o da matrícula, não o do plano atual. `renovar()` também não usa `Plano.valor` por padrão (usa o valor da matrícula anterior, a menos que `dto.valor` seja explicitamente informado). **Risco real: baixo**, mas o *comportamento* (permitir editar sem aviso) ainda é confuso pro operador, que pode achar que mudou algo que não mudou.

**R2 — Editar `Plano.periodicidade` com matrícula vinculada.** Este é o achado mais importante desta auditoria. Diferente de `valor`, `renovar()` **sempre** recalcula `dataFimPrevista` usando `plano.periodicidade` **lida no momento da renovação**, não a que valia quando a matrícula original foi criada (que nem fica registrada em lugar nenhum — ver P3). Cenário concreto: aluno assina um plano `MENSAL` em janeiro; em junho, a academia decide reestruturar o catálogo e muda esse mesmo `Plano` (mesmo `id`) pra `ANUAL`; quando esse aluno renovar em julho, o sistema calcula a nova vigência como 12 meses, não 1 — **sem qualquer alerta, confirmação ou possibilidade de o operador perceber**, porque a tela de renovação não mostra "isso mudou desde a última vez".

**R3 — Excluir um Plano com matrícula vinculada.** Confirmado no código: `remove()` faz soft-delete sem checar nada. Consequência concreta e verificada: `renovar()` faz `plano.findFirst({ where: { id: atual.planoId, deletedAt: null } })` e lança `NotFoundException('Plano não encontrado')` se o plano foi soft-deletado. Ou seja, **um Plano "removido" por engano (ou por limpeza de cadastro mal pensada) trava silenciosamente a renovação de qualquer aluno vinculado a ele**, com uma mensagem de erro que não aponta a causa raiz. Exatamente o cenário que a Regra 4 do pedido quer prevenir — e o guard proposto ali (bloquear a exclusão) resolve isso na origem.

**R4 — Geração de Mensalidade nunca acontecer.** O maior risco financeiro real: se ninguém clicar "Gerar mensalidades do mês" num determinado mês (esquecimento, feriado, troca de funcionário, confusão sobre de quem é a responsabilidade), **nenhuma cobrança é criada** — nem `PENDENTE`, nem nada. Não existe alerta, não existe e-mail, não existe indicador óbvio no Dashboard chamando atenção pra isso (o card "Receita Prevista" continua mostrando o valor esperado, calculado direto de `Matricula`, **mesmo que zero `Mensalidade` exista** — é fácil olhar o painel, ver um número em "Receita Prevista" e presumir que está tudo funcionando). Isso agrava especialmente **renovações** (P5): uma matrícula recém-renovada não tem nenhuma `Mensalidade` até alguém gerar manualmente as do mês corrente — se a renovação acontecer no fim do mês, a mensalidade daquele mês pode nunca ser gerada porque já passou a "janela" que alguém lembraria de clicar.

**R5 — Renomear um Plano reescreve o histórico exibido.** Como `planoNome` é sempre lido via join ao vivo (P3), renomear um `Plano` muda o nome exibido em **toda** matrícula vinculada a ele — passada, presente, futura, `CANCELADA`, `ENCERRADA` — instantaneamente, em qualquer tela/relatório que mostre `planoNome`. Não é uma inconsistência de dado (não quebra nada tecnicamente), mas quebra a garantia de "isso é o que foi contratado" que um contrato deveria ter — um relatório de "alunos que estavam no plano Bronze em março" ficaria errado se o Bronze foi renomeado pra Prata em abril.

**R6 — Concorrência na geração de Mensalidade (P6).** Baixo risco prático (ação administrativa manual, baixo volume de cliques simultâneos), mas sem rede de segurança de banco. Registrado por completude, não é prioridade.

---

## 4. Regras de negócio corretas (avaliação regra a regra do pedido)

1. **"Plano é só um modelo, não um contrato"** — ✅ já correto na essência (`planoId` imutável após criação, confirmado em `UpdateMatriculaDto` que nem declara o campo). Falta reforçar com snapshot de `nome`/`periodicidade` (regra 2).

2. **"Matrícula copia nome, valor, periodicidade, dia de vencimento, quantidade de meses, quantidade de aulas"** — parcialmente atendida. `valor`/`diaVencimento`: ✅ já copiados. `nome`/`periodicidade`: ❌ não copiados (P3) — **recomendo copiar os dois**. `quantidadeAulas`: hoje não é usado por nenhuma regra (P7) — recomendo copiar mesmo assim, por consistência de princípio ("é dado do contrato"), mas sem urgência, já que nada consome esse valor hoje. **"Quantidade de meses" não existe como campo separado no modelo atual** — a duração já é capturada com mais precisão via `dataInicio`/`dataFimPrevista` (datas reais, não um número abstrato de meses); recomendo **não** criar um campo redundante, mas isso é uma decisão de produto a confirmar com você.

3. **"Alteração de Plano com matrícula vinculada"** — meu parecer, avaliando as duas opções propostas: uma vez que a regra 2 esteja implementada (snapshot completo de nome/periodicidade na Matrícula), **nenhuma matrícula existente volta a ler esses campos do Plano depois de criada** — o que significa que bloquear a edição do Plano (opção A) deixa de ser estritamente necessário para *proteger contratos existentes*, porque eles já estão protegidos pelo snapshot. Recomendo uma variante refinada da opção B: **não bloquear a edição do Plano**, mas (i) garantir que o snapshot da regra 2 esteja implementado primeiro, e (ii) na tela de renovação, mostrar explicitamente quando o valor/periodicidade do Plano mudou desde a última vigência do aluno, exigindo confirmação explícita em vez de aplicar a mudança silenciosamente (resolve R2 na raiz). Bloquear completamente (opção A) é mais simples de implementar agora, mas tira flexibilidade comercial real (reajuste de preço de catálogo é uma operação legítima e frequente) sem necessidade, uma vez que o snapshot já resolve o risco de fato.

4. **"Exclusão de Plano com matrícula vinculada"** — ✅ concordo integralmente com o pedido. Bloquear com a mensagem exata sugerida; direcionar pra Inativar, que **já existe** (`PATCH /planos/:id/status`, `updateStatus()`) — não precisa de endpoint novo, só do guard em `remove()` e do tratamento de erro no frontend.

5. **"Mensalidades geradas automaticamente na criação da matrícula"** — **não recomendo a geração antecipada de todas as N mensalidades no momento da criação**, pelo motivo já documentado em `docs/17` item 2 e que continua válido: trava valor/desconto de meses futuros antes da hora, não acomoda reajuste ou desconto pontual decidido depois. A geração continua fazendo sentido "no momento certo" (mês a mês) — o problema real não é o *quando* gerar, é o *como* disparar (ver regra 8).

6. **"Renovação cria vigência, gera mensalidades, mantém histórico"** — "cria vigência" e "mantém histórico" já estão ✅ corretos (nova linha, `matriculaAnteriorId`, `ENCERRADA` na anterior, `Mensalidade` antiga nunca tocada). "Gera mensalidades automaticamente" ❌ não acontece hoje (P5) — recomendo resolver com o mesmo mecanismo da regra 8 (scheduler), não com uma chamada especial dentro de `renovar()`, pra manter uma única fonte de verdade de "quando gerar".

7. **"Histórico financeiro imutável"** — ✅ já 100% correto. `Mensalidade.valor` é congelado no momento da geração (cópia de `Matricula.valor` naquele instante), nunca recalculado depois. Nenhuma mudança necessária.

8. **"Dashboard só consulta; geração manual ainda faz sentido?"** — Dashboard: ✅ já é só leitura. Geração manual: **recomendo não fazer mais sentido como único mecanismo** — é o risco mais sério encontrado nesta auditoria (R4). Proposta: introduzir um scheduler (`@nestjs/schedule`, hoje ausente do projeto) que roda `MensalidadesService.gerar()` automaticamente (ex.: todo dia 1, pra todas as academias, pro mês corrente) — o valor cobrado continua sendo decidido no momento da geração (lido de `Matricula.valor`, que reflete qualquer edição feita até ali), preservando exatamente a flexibilidade que motivou a decisão original de não pré-gerar tudo. O botão manual **pode continuar existindo**, reenquadrado como ação de contingência (gerar um mês que passou batido, ou antecipar por algum motivo operacional) em vez de a única via.

9. **Integridade** — ver seção 3 (riscos R1-R6), que responde item a item o que foi pedido aqui.

---

## 5. Estratégia de migração

1. **Aditiva, sem quebrar dado existente.** Adicionar `planoNome String?` e `planoPeriodicidade Periodicidade?` (nullable) em `Matricula` — nenhuma coluna existente muda de tipo/nome.
2. **Backfill.** Para toda `Matricula` já existente, copiar o `nome`/`periodicidade` **atuais** do `Plano` vinculado para as colunas novas. Limitação honesta: se um Plano já foi renomeado ou mudou de periodicidade entre a criação de uma matrícula antiga e agora, o backfill não tem como recuperar o valor histórico real (essa informação nunca foi capturada) — o melhor possível é "nome/periodicidade atuais como aproximação", documentado como tal, não como dado 100% fidedigno para matrículas anteriores à migração.
3. **Tornar `NOT NULL`** depois do backfill confirmado.
4. **Atualizar `MatriculasService.create()`/`.renovar()`** para popular os dois campos sempre a partir daqui — cada nova matrícula (inclusive renovações) nasce com o snapshot completo.
5. **Atualizar `toResponse()`** para ler `matricula.planoNome`/`matricula.planoPeriodicidade` diretamente, em vez do `include: { plano: { select: { nome: true } } }`. O `planoId` continua existindo como FK para navegação (ex.: "ver o plano atual"), só deixa de ser a fonte do nome exibido.
6. **Contrato de API não muda de forma** — `planoNome` continua sendo uma string no JSON de resposta, só muda a origem interna do dado. Nenhum cliente (`admin_web`) precisa mudar por causa disso.

---

## 6. Impacto no banco

- `Matricula`: **+2 colunas** (`planoNome String`, `planoPeriodicidade Periodicidade`), ambas snapshot, preenchidas na criação/renovação. Migration + backfill (seção 5).
- `Plano`: **nenhuma mudança de schema** — `status` (`ATIVO`/`INATIVO`) já existe e já cobre "inativar" (regra 4).
- `Mensalidade`: **nenhuma mudança necessária** para as regras 5-8. Opcional, prioridade baixa: colunas explícitas `mes Int`/`ano Int` + `@@unique([matriculaId, mes, ano])` para reforçar P6 com constraint de banco de verdade (hoje a checagem de duplicidade é por range de `dataVencimento`, que já funciona, só não tem essa segunda camada). Não é bloqueante.
- Scheduler (regra 8): **nenhuma tabela nova** — `MensalidadesService.gerar()` já existe e já é idempotente por design; só passa a ser chamado por um cron além de (ou em vez de) um clique.

---

## 7. Impacto no backend

- `matriculas.service.ts` — `create()`/`renovar()` passam a popular `planoNome`/`planoPeriodicidade`; `toResponse()` para de ler via `include`.
- `matricula-response.dto.ts` (e o modelo `Matricula` em `shared_core`) — sem mudança de forma, só de origem do dado.
- `planos.service.ts` — `remove()` ganha guard: contar `Matricula` vinculada (`matricula.count({ where: { planoId: id, deletedAt: null } })`), lançar `ConflictException('Este plano possui alunos vinculados e não pode ser removido.')` se `> 0`. `update()` — decisão pendente (seção 4, regra 3): se optar por não bloquear, nenhuma mudança aqui além do que a regra 2 já resolve.
- Novo: infraestrutura de scheduler — dependência nova (`@nestjs/schedule`), um serviço novo (ex. `MensalidadesSchedulerService`) chamando `MensalidadesService.gerar()` para todas as academias elegíveis, numa cadência a decidir (diária checando o 1º dia do mês, ou mensal). Maior peça de infraestrutura desta lista — é a única das mudanças recomendadas que introduz uma dependência nova no projeto.
- Nenhuma mudança em `AuditAction` — os valores existentes (`PLANO_DELETED`, `MATRICULA_STATUS_CHANGED`, `MENSALIDADE_GERADA`) já cobrem os eventos relevantes; a exclusão bloqueada de Plano simplesmente passa a não gerar mais `PLANO_DELETED` nesse cenário específico (continua existindo para quando a exclusão for de fato permitida).

---

## 8. Impacto no frontend

- `plano_detail_screen.dart` — botão "Remover": tratar o novo erro (`ConflictException`, HTTP 409) com uma mensagem clara na tela, oferecendo "Inativar" (`_alternarStatus`, **já existe** na mesma tela) como alternativa direta — sem endpoint novo a consumir.
- `mensalidades_screen.dart` — botão "Gerar mensalidades do mês" continua existindo, mas se a geração automática (regra 8) for implementada, o texto/contexto ao redor dele deveria deixar claro que é uma ação de contingência, não a via principal — evita o operador achar que "esqueceu de gerar" quando na verdade o cron já cobriu o mês.
- `matricula_detail_screen.dart` (renovação) — se a recomendação da regra 3 (confirmação explícita quando o Plano mudou desde a última vigência) for adotada, precisa de um aviso visual novo nessa tela. **Tratar como sprint separada**, não faz parte do escopo mínimo desta correção estrutural.
- `plano_form_screen.dart` — sem mudança de fluxo se a decisão for não bloquear edição (regra 3); se decidirem pela opção A (bloquear), os campos comerciais precisariam ficar desabilitados com uma explicação quando o plano tiver matrícula vinculada.
- Nenhuma tela nova necessária para o essencial desta correção (guard de exclusão + snapshot + scheduler são, em grande parte, mudanças de backend/dado; o frontend já exibe `planoNome` e afins do jeito que sempre exibiu, só a fonte do dado muda).

---

## 9. Ordem recomendada de implementação

1. **Guard de exclusão de Plano com matrícula vinculada** (regra 4) — maior risco concreto já observável (R3), menor esforço, zero migration. Resolve sozinho, sem depender de mais nada.
2. **Snapshot de `nome`/`periodicidade` na Matrícula** (regra 2) — migration + backfill + services. Resolve P3/R5 de raiz e é pré-requisito pra decidir com segurança a regra 3 (edição de Plano).
3. **Decisão final sobre edição de Plano** (regra 3) — com o snapshot de (2) já valendo, decidir entre bloquear ou permitir livremente com aviso na renovação (R2).
4. **Scheduler de geração automática de Mensalidade** (regras 5/6/8) — maior esforço (infraestrutura nova), mas é o risco financeiro mais sério (R4) — não deixar para o final só porque é o mais trabalhoso.
5. *(Opcional, menor prioridade)* Aviso explícito na tela de renovação quando valor/periodicidade do Plano mudou.
6. *(Opcional, menor prioridade)* Colunas `mes`/`ano` + constraint de unicidade em `Mensalidade` (reforço de P6).

## 10. O que pode quebrar compatibilidade

- **Snapshot de nome/periodicidade (item 2)**: aditivo, não quebra nada — mesma forma de resposta de API, mesmo contrato pro frontend.
- **Guard de exclusão de Plano (item 1)**: muda comportamento observável — qualquer fluxo/script que hoje dependa de conseguir excluir um plano com matrícula vinculada passa a receber 409. Verificado: `test/planos.e2e-spec.ts` **não tem** nenhum teste hoje que exclua um plano com matrícula vinculada, então nada quebra na suíte atual — mas é o tipo de mudança que merece um teste e2e novo cobrindo o cenário, não só a ausência de quebra no que já existe.
- **Guard de edição de Plano, se a opção A (bloquear) for escolhida na regra 3**: quebra o comportamento atual de verdade (`update()` hoje aceita qualquer edição sempre) — qualquer uso real de "reajustar preço de um plano em uso" pararia de funcionar sem uma alternativa (ex.: duplicar o plano). Por isso a recomendação da seção 4 é não bloquear, condicionado ao snapshot já estar implementado.
- **Scheduler automático (item 4)**: não quebra nada tecnicamente (é aditivo — o botão manual continua funcionando), mas é uma **mudança de comportamento operacional visível** pro dono da academia: mensalidades passam a aparecer sozinhas, sem ação manual. Vale comunicar como mudança de produto na entrega, não só como correção técnica silenciosa.

---

## Outras observações estruturais encontradas durante a auditoria (fora das 10 regras, mas relevantes)

- `Plano.quantidadeAulas` (P7) não é usado por nenhuma regra hoje — se a intenção de produto é realmente limitar quantas aulas um aluno pode reservar por período conforme o plano, essa regra **não existe em lugar nenhum do módulo de Agenda** (verificado em `turma-alunos.service.ts` — só há checagem de capacidade da turma, nunca de cota do aluno). Não é um bug desta auditoria, é uma lacuna de escopo a decidir separadamente: o campo é só informativo por design, ou falta implementar o enforcement?
- A checagem de duplicidade de `Mensalidade` (P6) usa range de data (`dataVencimento: { gte: inicio, lt: fim }`), não um par `mes`/`ano` explícito — funciona corretamente hoje, mas é bom registrar que qualquer futura constraint de banco (seção 6) precisaria desses dois campos explícitos, já que `dataVencimento` sozinha não é um bom alvo de `@@unique` (o dia varia por matrícula via `diaVencimento`).
