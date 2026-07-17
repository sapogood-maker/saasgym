# 31 — Incidente: mensalidades duplicadas em produção

## Contexto

A migration `20260717102823_integridade_financeira_periodicidade_e_unicidade`
(Sprint de Integridade Financeira, docs/29) falhou ao rodar em produção:

```
ERROR: could not create unique index "mensalidades_matriculaId_dataVencimento_key"
DETAIL: Key (matriculaId, dataVencimento) is duplicated.
```

A auditoria em docs/29 afirmou que a duplicidade não existia — essa
afirmação estava incorreta porque só analisou os fluxos **novos**
(`MatriculasService.create`/`renovar` + `gerarMensalidadesDaVigencia`).
Ela nunca auditou o endpoint **legado**, `MensalidadesService.gerar()`
(existente desde o Módulo 3, rodando em produção há meses), que é onde
o problema realmente está.

## Causa raiz

Duas falhas independentes em `MensalidadesService.gerar()`, ambas já
corrigidas nesta sprint:

**1) A checagem de "já existe" ignorava soft-delete (determinística,
sem precisar de concorrência)**

```ts
const jaExiste = await this.prisma.forTenant().mensalidade.findFirst({
  where: { matriculaId: matricula.id, dataVencimento: { gte: inicio, lt: fim }, deletedAt: null },
});
```

Fluxo real e reproduzível:

1. `gerar()` cria a mensalidade de julho (linha A, `deletedAt = null`).
2. Erro de cadastro identificado → `MensalidadesService.remove()`
   soft-deleta a linha A (`deletedAt = agora`; permitido, pois só
   bloqueia remoção quando `status = PAGA`).
3. `gerar()` roda de novo pra julho → o filtro `deletedAt: null` não
   enxerga a linha A → cria a linha B, mesma chave, `deletedAt = null`.

Resultado: duas linhas físicas com o mesmo `(matriculaId,
dataVencimento)`.

**2) Checagem e criação não eram atômicas (race condition)**

O `findFirst` (SELECT) e o `create` (INSERT) não estavam dentro de
transação nem lock algum. Duplo clique no botão "Gerar mensalidades",
duas abas abertas ou um retry de rede após timeout: duas requisições
concorrentes passam pelo SELECT antes de qualquer INSERT confirmar →
duas linhas ativas para a mesma chave.

**Por que a migration inteira foi revertida em produção**: `CREATE
UNIQUE INDEX` roda dentro da mesma transação de toda a migration
(nenhuma statement ali exige rodar fora de transação). A falha no
último passo reverteu tudo — inclusive `matriculas.periodicidade`, que
hoje não existe em produção.

## Decisão: índice parcial vs. índice completo

Cogitou-se inicialmente um índice único **parcial**
(`WHERE "deletedAt" IS NULL`), que teria resolvido o erro sem tocar em
nenhuma linha. Descartado porque:

- Só protege linhas ativas — duas linhas com a mesma chave, uma delas
  soft-deletada, continuariam coexistindo livremente.
- Não corrige a causa raiz (1): o bug de `gerar()` continuaria
  produzindo duplicidade histórica silenciosamente, sem nunca mais
  disparar erro.
- A regra de negócio real é "uma matrícula nunca tem duas cobranças
  pro mesmo vencimento", **inclusive no histórico** — soft-delete é
  correção de cadastro, não anula o fato de que aquele vencimento já
  foi gerado uma vez.

Optou-se por um índice único **completo** (sem `WHERE`), que exige
consolidar cada grupo duplicado em exatamente uma linha física antes
de criar o índice.

## Algoritmo de consolidação (determinístico, sem empate implícito)

Para cada grupo `(matriculaId, dataVencimento)` com mais de uma linha,
critério de desempate total, nesta ordem:

1. **Status: `PAGA` > `PENDENTE` > `CANCELADA`.**
   `ATRASADA` não existe como status armazenado — é sempre calculado
   em `MensalidadesService.toResponse` (`status = PENDENTE AND
   dataVencimento` no passado), nunca persistido, portanto não entra
   nesta priorização.
   `PAGA` nunca é removida: é a única que pode ter `Lancamento`
   vinculado (criado atomicamente dentro de `marcarPaga`), então
   mantê-la sempre elimina de saída qualquer risco de órfão.
2. **`deletedAt IS NULL` antes de `deletedAt IS NOT NULL`** — entre
   linhas de mesmo status, prefere a ativa.
3. **`createdAt` mais antigo primeiro** — a linha original; as demais
   são artefatos do bug.
4. **`id` (UUID) como desempate final absoluto** — garante ordenação
   total; nunca há duas linhas com o mesmo `id`, então o Postgres
   nunca precisa resolver um empate arbitrariamente.

## Auditoria de referências (FKs) à tabela `mensalidades`

Única referência existente em todo o schema:
`lancamentos.mensalidadeId` (constraint
`lancamentos_mensalidadeId_fkey`, `ON DELETE SET NULL`, migration
`20260712232032_financeiro`). Nenhuma outra tabela referencia
`Mensalidade`.

A migration inclui um gate explícito (`DO $$ ... RAISE EXCEPTION`) que
verifica, antes de remover qualquer linha, se algum registro marcado
para remoção está referenciado por um `Lancamento`. Isso não deveria
acontecer nunca (regra 1 do algoritmo garante que `PAGA` — a única com
`Lancamento` — nunca é candidata a remoção), mas se acontecer por
qualquer motivo não previsto, a migration inteira é abortada com erro
explícito em vez de deixar o Postgres silenciosamente setar
`mensalidadeId = NULL` num `Lancamento` e órfão um pagamento.

## O que a migration faz

Arquivo:
`backend/prisma/migrations/20260717150000_consolida_mensalidades_duplicadas_indice_completo/migration.sql`

1. Reaplica `matriculas.periodicidade` de forma idempotente (`ADD
   COLUMN IF NOT EXISTS` + backfill só onde `NULL` + `SET NOT NULL`) —
   necessário porque o rollback em produção removeu essa coluna
   também; nos ambientes onde a migration anterior teve sucesso, são
   no-ops.
2. Calcula o ranking de desempate em uma tabela temporária
   (`_mensalidades_rank`, `ON COMMIT DROP`).
3. Roda o gate de FK (aborta com `RAISE EXCEPTION` se necessário).
4. **Arquiva** cada linha perdedora, integralmente, em
   `mensalidades_duplicatas_removidas_20260717` (tabela nova, criada
   pela própria migration) antes de remover — nenhum dado é
   descartado, só sai da tabela operacional.
5. Remove (hard delete) só as linhas já arquivadas — nunca uma `PAGA`.
6. Grava um resumo da consolidação em `audit_logs` (reaproveitando a
   action `MENSALIDADE_DELETED` já existente — criar um novo valor de
   enum e usá-lo na mesma transação não é permitido pelo Postgres),
   com `gruposDuplicados`, `registrosArquivados`, `registrosRemovidos`
   e o nome da tabela de arquivo. Só grava se algo de fato foi
   consolidado.
7. Recria o índice único, desta vez completo (sem `WHERE`).

**Idempotente**: reexecutável em qualquer ambiente. Sem duplicados,
os passos 3–6 afetam zero linhas e não gravam nada; o índice é
recriado (`DROP INDEX IF EXISTS` + `CREATE UNIQUE INDEX`) de forma
segura tanto onde ele já existia (dev, versão antiga/plana) quanto
onde nunca existiu (produção).

## Correção complementar no código (fora da migration)

`MensalidadesService.gerar()` deixou de fazer a checagem prévia
(`findFirst` com `deletedAt: null`) e passou a confiar exclusivamente
na constraint do banco: tenta o `create` diretamente e trata `P2002`
(violação de unique) como "já existe, pular". Sem esse ajuste, assim
que o índice completo existisse, o próprio `gerar()` voltaria a
produzir os dois cenários de duplicidade — só que agora como erro 500
não tratado, em vez de duplicidade silenciosa.

## Impacto

- **Dados**: nenhuma linha `PAGA`/com pagamento é tocada. Linhas
  duplicadas `PENDENTE`/`CANCELADA` perdedoras saem de `mensalidades`
  e passam a existir em `mensalidades_duplicatas_removidas_20260717`
  (histórico integral preservado, fora da tabela operacional).
- **Aplicação**: nenhuma tela ou regra de negócio muda de
  comportamento visível — `gerar()` continua idempotente pro usuário
  final, só muda o mecanismo interno de detecção de duplicidade.
- **Operacional**: a migration `20260717102823` está marcada como
  `failed` em `_prisma_migrations` em produção (rollback transacional
  completo). Antes do próximo `prisma migrate deploy`, é necessário
  rodar manualmente:
  ```
  npx prisma migrate resolve --rolled-back 20260717102823_integridade_financeira_periodicidade_e_unicidade
  ```
  Esse comando não foi executado por esta sessão — é um passo de
  deploy contra o banco de produção, fora do escopo de alteração de
  código.

## Estratégia de rollback

- A migration nova é aditiva e não destrutiva de forma irreversível:
  toda linha removida está arquivada em
  `mensalidades_duplicatas_removidas_20260717` com timestamp
  (`removidoEm`) e motivo (`motivoRemocao`). Reverter manualmente (caso
  necessário) é reinserir essas linhas de volta em `mensalidades`.
- Se o índice único completo causar algum efeito colateral inesperado
  em produção após o deploy, ele pode ser removido isoladamente
  (`DROP INDEX "mensalidades_matriculaId_dataVencimento_key"`) sem
  precisar reverter a consolidação de dados — são passos independentes
  no arquivo da migration.
- `_prisma_migrations` guarda o registro de que essa migration rodou;
  reverter via `prisma migrate resolve --rolled-back` desta nova
  migration só deve ser feito se o `DROP INDEX` acima também for
  aplicado manualmente (a resolução não desfaz DDL/DML já aplicado).

## Testes

Cenários cobertos manualmente antes da entrega (a suíte automatizada
de `mensalidades`/`matriculas`/`planos` do backend não cria
duplicidade histórica, então não exercita a consolidação — este é um
script de dado real, validado por leitura cuidadosa e por rodar contra
uma cópia de dados com duplicidade simulada):
- Grupo com uma `PAGA` + uma `PENDENTE` duplicada → `PAGA` sobrevive,
  `PENDENTE` arquivada e removida.
- Grupo com uma ativa + uma soft-deletada, mesmo status → ativa
  sobrevive.
- Grupo sem duplicidade → nenhuma linha tocada.
- Banco já com o índice antigo (plano) aplicado (cenário dev) →
  `DROP INDEX IF EXISTS` + recriação funciona sem erro.
