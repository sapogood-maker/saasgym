# Módulo 2 — Matrículas: análise de domínio (pré-implementação)

Escrito ao final do Módulo 1 (Planos), antes de qualquer código do Módulo 2. `Matricula` é a entidade mais central do ERP: é ela que liga `Aluno` a `Plano`, e é a partir dela que o Módulo 3 (Financeiro) vai gerar `Mensalidade` e o Módulo de Agenda vai decidir quem pode entrar numa `Turma`. Um modelo mal desenhado aqui se propaga para dois módulos inteiros — por isso este documento existe antes de qualquer `schema.prisma`/service/tela, seguindo o mesmo fluxo já usado em todo o projeto (analisar → propor → aprovar → implementar), só que desta vez aplicado ao **modelo de domínio**, não a uma tela.

Nenhuma decisão aqui está implementada ainda. Este documento propõe um modelo e isola explicitamente as decisões que são de negócio (do dono do produto), não técnicas — marcadas na seção final.

## O papel da Matrícula no ERP

- **Comercial**: liga um `Aluno` a um `Plano` por um período, com o valor efetivamente acordado (que pode divergir do preço de tabela do `Plano` por desconto negociado).
- **Financeiro** (Módulo 3): fonte dos dados que geram `Mensalidade` — valor, dia de vencimento, vigência.
- **Agenda** (módulo futuro): matrícula ativa é a condição de elegibilidade para reservar `Aula`.
- **Negócio**: é a base de métricas que só um ERP de verdade oferece — taxa de renovação, churn, tempo médio de permanência, motivo de cancelamento. Isso é o que diferencia "um formulário que grava no banco" de "uma ferramenta que ajuda a administrar a academia" ([[feedback_academia_facing_value]]) — por isso o modelo abaixo prioriza preservar histórico completo, não só o estado atual.

## Decisões de modelo propostas

### 1. `valor` é uma cópia (snapshot) do `Plano.valor` no momento da matrícula, não uma referência viva

Se o dono da academia reajustar o preço do plano "Musculação" de R$ 99 pra R$ 119, os alunos já matriculados **não** devem ser cobrados automaticamente pelo novo valor — isso só vale pra matrículas novas ou renovações. `Matricula.valor` é copiado de `Plano.valor` na criação e pode ser editado independentemente (desconto negociado por aluno). `Matricula.planoId` continua existindo como FK, mas só para navegação/relatório ("quantos alunos estão no plano X hoje"), nunca como fonte de verdade do valor cobrado. Mesmo princípio de normalização monetária já documentado em `docs/15-design-system-e-padrao-crud.md`.

### 2. Novo enum `MatriculaStatus` — não reaproveita `UserStatus`

Todo o resto do sistema até aqui (`Aluno`, `Professor`, `Plano`) usa `UserStatus` (`ATIVO`/`INATIVO`), que é suficiente porque "inativo" ali só significa "escondido da operação do dia a dia". Matrícula precisa de mais granularidade porque cada estado tem uma implicação de negócio diferente:

- `ATIVA` — cobrando, aluno pode frequentar.
- `TRANCADA` — pausada por período (viagem, lesão); não cobra, não conta pra capacidade de turma, mas **não é o fim do contrato** — volta a `ATIVA` depois.
- `CANCELADA` — encerrada por decisão (do aluno ou da academia) antes do fim natural da vigência.
- `ENCERRADA` — chegou ao fim da vigência (`dataFim`) sem renovação.

Reaproveitar `UserStatus` aqui esconderia a diferença entre "trancado" e "cancelado" atrás de um único `INATIVO` — perda de informação que o dono da academia precisa pra decidir se liga pro aluno oferecendo reativação (trancado) ou entender por que perdeu o cliente (cancelado, com motivo).

### 3. Cada renovação cria uma nova `Matricula`, nunca sobrescreve `dataFim` da mesma linha

Alternativa descartada: manter uma única linha por aluno e só empurrar `dataFim` a cada renovação. Isso é mais simples de consultar ("qual a matrícula do aluno X"), mas destrói o histórico — não dá pra saber quantas vezes o aluno renovou, nem reconstruir o valor cobrado em cada período (útil pra Financeiro/relatório). Cada renovação vira uma nova `Matricula`; a anterior transita para `ENCERRADA`. Um campo opcional de auto-relacionamento (`matriculaAnteriorId`) liga a nova à antiga para navegação — não estritamente necessário no MVP (dá pra inferir por `alunoId` + ordenação por `dataInicio`), mas barato de incluir agora e caro de adicionar depois numa tabela já populada.

### 4. Regra "uma matrícula `ATIVA` por vez por aluno" — aplicada no service, não como constraint de banco

Uma constraint de unicidade no banco (`@@unique([alunoId], where: status = ATIVA)`) não é suportada diretamente pelo Prisma/Postgres sem índice parcial manual via migration SQL — e mesmo que fosse, `TRANCADA`/`CANCELADA`/`ENCERRADA` precisam conviver no histórico da mesma tabela sem violar a constraint. A regra "só uma `ATIVA` por aluno" fica no `MatriculasService`, verificada antes de criar/ativar (mesmo padrão de outras regras de negócio do projeto, ex. CPF único por academia é constraint de banco porque é verdadeiramente absoluta; isso aqui não é). **Esta regra em si é uma decisão de negócio, não técnica — ver seção final.**

### 5. Trancamento simples no MVP — sem tabela de histórico de congelamentos

Campos direto em `Matricula` (`trancadoEm`, `trancamentoMotivo`) em vez de uma entidade `Trancamento` separada com N períodos por matrícula. Reativar soma os dias congelados a `dataFim` (quem tranca 15 dias não perde 15 dias de plano) e limpa os dois campos. Suporta um período de trancamento por vez — se o aluno tranca, reativa e tranca de novo, o segundo trancamento sobrescreve os campos do primeiro (o histórico do primeiro trancamento não fica pesquisável isoladamente, só o efeito líquido em `dataFim`). Mesmo princípio já usado no projeto pra `AppCurrencyField`/`CrudRepository`: não construir a tabela de histórico granular até existir uma repetição real que peça por ela.

### 6. `diaVencimento` entra agora — `desconto`/`multa` ficam pra `Mensalidade` (Financeiro, Módulo 3)

`diaVencimento` (dia do mês, 1-31) é dado do **contrato** (quando o aluno combinou de pagar), não da cobrança em si — pertence à Matrícula, default = dia de `dataInicio`, editável. Já `desconto`/`multa` são dados **de cada cobrança individual** (uma mensalidade pode ter multa por atraso, outra não) — `docs/02-banco-de-dados.md` já reserva esses campos para `Mensalidade`, e este documento mantém essa divisão: `Matricula.valor` é o valor mensal acordado; ajustes por cobrança específica são problema do Módulo 3, não duplicados aqui.

### 7. `Matricula` não referencia `Modalidade` — fica de fora do Módulo 2

O roadmap original (`docs/08-roadmap.md`, Sprint 4) previa `Modalidade` (nome/cor) junto com `Matricula`. Decisão proposta: adiar `Modalidade` para quando o módulo de Agenda existir de fato — é lá que ela tem uso real (`Turma.modalidadeId`, capacidade, cor na grade semanal). Acoplar `Matricula` a `Modalidade` agora seria modelar pra um módulo que ainda não existe, sem um segundo caso de uso real confirmando a forma certa — mesmo critério de "componente nasce de necessidade real" já aplicado ao Design System, agora aplicado ao modelo de dados. `Matricula` no Módulo 2 é puramente comercial: Aluno × Plano × período.

### 8. "Remover" não é soft-delete puro — é "Cancelar matrícula" (motivo obrigatório)

Em Aluno/Professor/Plano, "Remover" = soft delete (`deletedAt`), reversível só via banco, sem necessidade de explicar o motivo — faz sentido porque remover um cadastro é uma limpeza administrativa. Numa Matrícula, a ação equivalente do dia a dia é **cancelar um contrato**, que é um evento de negócio relevante (motivo de saída, dado que interessa ao relatório de churn), não uma limpeza de cadastro. Proposta: o botão principal de encerramento no painel de detalhe chama `PATCH /matriculas/:id/status` para `CANCELADA` com `motivoCancelamento` obrigatório (mesmo endpoint de mudança de status já usado por Aluno/Professor/Plano, sem reinventar), preservando a linha inteira e visível no histórico do aluno. `deletedAt` continua existindo no model (mesma família de campos por consistência com o resto do schema), mas reservado a correção de erro de cadastro (matrícula criada errada por engano) — não deve nem precisa ter um botão "Remover" de destaque igual ao de Aluno/Professor/Plano na tela de detalhe; se existir, é uma ação secundária, não a primária.

### 9. `dataFimPrevista` (imutável) separada de `dataFim` (vigente)

Depois da confirmação das 3 decisões, o dono do produto pediu essa distinção para não perder o dado original do contrato: `dataFimPrevista` é calculada **uma única vez**, na criação (`dataInicio` + duração da `Periodicidade` do `Plano`), e nunca muda depois — é "o que foi combinado". `dataFim` é a data de corte **vigente** — nasce igual a `dataFimPrevista`, mas é empurrada pra frente quando a matrícula é reativada depois de um trancamento (soma os dias congelados, item 5). Isso permite relatórios que antes eram impossíveis com um único campo (ex.: "em média, quanto o trancamento estende a permanência de um aluno") sem perder a data de corte operacional que Financeiro/Agenda realmente usam (`dataFim`).

### 10. `motivoCancelamento` vira categorizado (`MotivoCancelamento`) + detalhe livre

Um único campo de texto livre é ambíguo pra relatório — "o aluno saiu porque..." em texto livre não é agrupável (não dá pra responder "quantos cancelamentos por inadimplência este mês" sem reler linha por linha). Novo enum `MotivoCancelamento` (`ALUNO_SOLICITOU`/`INADIMPLENCIA`/`ACADEMIA_CANCELOU`/`OUTRO`) captura a categoria; `motivoCancelamentoDetalhe String?` continua livre para contexto adicional, **obrigatório apenas quando a categoria é `OUTRO`** (senão a categoria sozinha já basta). Mesmo raciocínio de "dado estruturado > texto livre quando existe valor de relatório real" já aplicado ao resto do domínio (`MatriculaStatus` em vez de reaproveitar `UserStatus`, item 2). `trancamentoMotivo` **permanece texto livre** — não há ainda um segundo caso real pedindo categorização ali, mesmo critério de "3ª repetição confirmada" que já rege o resto do projeto.

### 11. `createdByUserId` — auditoria de quem criou a matrícula

`Matricula.createdByUserId` (obrigatório, FK pra `User`) registra qual usuário autenticado processou a matrícula — toda criação passa por um `ACADEMIA_ADMIN`/`RECEPCIONISTA` logado, nunca é anônima. Isso é complementar ao `AuditLog` (que já registra o evento com ator/IP/User-Agent): o `AuditLog` é a trilha *de eventos*, `createdByUserId` é o dado *denormalizado na própria linha* — permite responder "quais matrículas o recepcionista X criou" com uma query direta na tabela de negócio, sem depender de reconstrução via log. Mesmo padrão que already existe implicitamente em `AuditLog.userId`, agora também no registro de negócio em si.

### 12. Regra oficial: matrícula nunca muda de plano

Formalizando o que os itens 3 e 4 já implicavam: **`planoId` é imutável após a criação.** Não existe (nem vai existir) um `PATCH /matriculas/:id` que troque o plano de uma matrícula existente — upgrade, downgrade e renovação são **sempre** a mesma operação: encerrar a matrícula atual (`ENCERRADA` se por vigência natural, `CANCELADA` se por decisão) e criar uma nova matrícula (com `matriculaAnteriorId` apontando pra anterior quando aplicável). Na prática: `UpdateMatriculaDto` **não tem** campo `planoId` — não é "ignorado se enviado", é ausente do tipo, mesmo padrão de `UpdateUserProfileDto` (`docs/14-alunos-professores.md`) que nem declara `role` como campo aceito. Isso elimina de raiz qualquer ambiguidade sobre "isso é uma edição ou uma troca de plano disfarçada de edição".

## Rascunho de schema (Prisma) — para validação, não para aplicar ainda

```prisma
enum MatriculaStatus {
  ATIVA
  TRANCADA
  CANCELADA
  ENCERRADA
}

enum MotivoCancelamento {
  ALUNO_SOLICITOU
  INADIMPLENCIA
  ACADEMIA_CANCELOU
  OUTRO
}

model Matricula {
  id         String   @id @default(uuid())
  academiaId String
  academia   Academia @relation(fields: [academiaId], references: [id], onDelete: Cascade)

  alunoId String
  aluno   Aluno  @relation(fields: [alunoId], references: [id])

  planoId String
  plano   Plano  @relation(fields: [planoId], references: [id]) // imutável após a criação — item 12

  createdByUserId String
  createdByUser   User   @relation(fields: [createdByUserId], references: [id])

  valor         Decimal @db.Decimal(10, 2) // snapshot de Plano.valor na criação
  diaVencimento Int                        // 1-31

  dataInicio      DateTime
  dataFimPrevista DateTime // calculada 1x na criação, nunca muda — item 9
  dataFim         DateTime // vigente; estendida por trancamento

  status MatriculaStatus @default(ATIVA)

  trancadoEm        DateTime?
  trancamentoMotivo String?

  motivoCancelamento        MotivoCancelamento?
  motivoCancelamentoDetalhe String? // obrigatório só quando motivoCancelamento = OUTRO — item 10

  matriculaAnteriorId String?    @unique
  matriculaAnterior   Matricula? @relation("Renovacao", fields: [matriculaAnteriorId], references: [id])
  matriculaRenovada   Matricula? @relation("Renovacao")

  deletedAt DateTime?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([academiaId])
  @@index([alunoId])
  @@index([planoId])
  @@map("matriculas")
}
```

`User` ganha a relação oposta `matriculasCriadas Matricula[]` (item 11).

Novas ações de `AuditAction`: `MATRICULA_CREATED`, `MATRICULA_UPDATED`, `MATRICULA_STATUS_CHANGED` (cobre ativar/trancar/cancelar/renovar via `metadata`), `MATRICULA_DELETED` — mesmo padrão de `Plano`.

## Fora do escopo do Módulo 2 (deliberado, não esquecido)

- `Modalidade` como entidade própria (item 7).
- Histórico granular de múltiplos trancamentos por matrícula (item 5).
- Geração de `Mensalidade` — Matrícula só guarda os dados-fonte; a geração em si é Módulo 3.
- Qualquer integração com `Turma`/`Aula` — módulo de Agenda ainda não existe.
- Upgrade/downgrade de plano no meio da vigência (trocar de plano sem esperar o fim) — tratado como cancelar a atual + criar uma nova, não como uma operação dedicada, até haver um caso real pedindo o contrário.

## Ponta solta encontrada durante a análise (cosmética, não bloqueia)

`AlunoDetailScreen` (`admin_web/lib/features/alunos/aluno_detail_screen.dart:268`) e `DashboardScreen` (`admin_web/lib/features/dashboard/dashboard_screen.dart:58`) ainda usam a tag antiga `'SPRINT 5 · MATRÍCULAS'` nos `EmptyState.comingSoon` — de antes da convenção `'MÓDULO N'` (adotada no MS5). Corrigir para `'MÓDULO 2 · MATRÍCULAS'` faz parte da implementação do Módulo 2, não deste documento.

## Decisões de negócio confirmadas pelo dono do produto (2026-07-11)

1. **Concorrência**: sempre 1 matrícula `ATIVA` por aluno por vez. Trocar de plano cancela a atual e cria uma nova — confirma o item 4 como está.
2. **Trancamento**: um único período de congelamento ativo por vez, sem tabela de histórico — confirma o item 5 como está.
3. **Renovação**: cada renovação cria uma nova linha, preservando a anterior como `ENCERRADA` — confirma o item 3 como está.

O modelo proposto na seção "Rascunho de schema" acima está validado e pronto para ir a plano de implementação (MS1 do Módulo 2 — schema + migration + `MatriculasService`).

## Histórico

- **2026-07-11**: primeira versão — análise de domínio antes de qualquer implementação do Módulo 2, conforme decisão de encerramento do Módulo 1.
- **2026-07-11**: as 3 decisões de negócio em aberto foram confirmadas pelo dono do produto, todas seguindo a opção recomendada. Modelo de domínio considerado fechado para o MVP do Módulo 2.
- **2026-07-11**: refinamentos finais antes da implementação — `dataFimPrevista` (item 9), `motivoCancelamento` categorizado (item 10), `createdByUserId` (item 11) e regra oficial de imutabilidade de `planoId` (item 12). Aprovado para o MS1 (migration + `MatriculasService` + endpoints + auditoria + testes e2e).
