-- Correção pós-produção da migration 20260717102823 (docs/29 +
-- docs/31-incidente-mensalidades-duplicadas.md).
--
-- Essa migration anterior falhou em produção ao tentar criar
-- UNIQUE(matriculaId, dataVencimento) em "mensalidades": já existiam
-- linhas duplicadas na chave, geradas pelo endpoint legado
-- MensalidadesService.gerar() por dois motivos (ver docs/31 pra
-- análise completa): (1) a checagem de "já existe" antes de criar
-- filtrava deletedAt = null, então soft-delete (remove()) seguido de
-- gerar() de novo criava uma segunda linha pra mesma chave; (2) a
-- checagem e a criação não eram atômicas (sem transação/lock), então
-- duas chamadas concorrentes passavam pela checagem antes de
-- qualquer INSERT confirmar.
--
-- Como CREATE UNIQUE INDEX roda dentro da mesma transação da
-- migration inteira (nenhuma statement aqui exige rodar fora de
-- transação), a falha reverteu tudo em produção — inclusive
-- matriculas.periodicidade. O passo 1 abaixo reaplica essa coluna de
-- forma idempotente; nos ambientes onde a migration anterior teve
-- sucesso, os comandos são no-ops.
--
-- Migration idempotente por completo: reexecutável em qualquer
-- ambiente (com ou sem duplicidade, com ou sem a coluna/índice já
-- existentes) sem erro e sem efeito colateral em uma segunda
-- execução.

-- ============================================================
-- 1) matriculas.periodicidade — reaplicação defensiva
-- ============================================================
ALTER TABLE "matriculas" ADD COLUMN IF NOT EXISTS "periodicidade" "Periodicidade";

UPDATE "matriculas" m
SET "periodicidade" = p."periodicidade"
FROM "planos" p
WHERE m."planoId" = p."id" AND m."periodicidade" IS NULL;

ALTER TABLE "matriculas" ALTER COLUMN "periodicidade" SET NOT NULL;

-- ============================================================
-- 2) Consolidação de mensalidades duplicadas em
--    (matriculaId, dataVencimento)
--
--    Prioridade de desempate, total e sem empate implícito:
--      a) status: PAGA > PENDENTE > CANCELADA.
--         "ATRASADA" não existe como status armazenado — é sempre
--         calculado em MensalidadesService.toResponse a partir de
--         (status = PENDENTE AND dataVencimento no passado), nunca
--         persistido, então não entra nesta priorização.
--         PAGA nunca é removida: é a única que pode ter Lancamento
--         vinculado (marcarPaga cria o Lancamento e a PAGA juntos, na
--         mesma transação), então mantê-la sempre elimina de saída
--         qualquer risco de orfandade.
--         PENDENTE > CANCELADA: entre as não pagas, a PENDENTE ainda
--         representa uma cobrança em aberto que a academia
--         eventualmente vai cobrar/receber; a CANCELADA já é um
--         estado terminal — preservar a PENDENTE é o que preserva
--         valor de negócio real quando as duas competem pela mesma
--         chave.
--      b) deletedAt IS NULL antes de deletedAt IS NOT NULL — entre
--         duas linhas de mesmo status, prefere a ativa.
--      c) createdAt mais antigo primeiro — a linha original; as
--         demais são artefatos do bug.
--      d) id (UUID) como desempate final absoluto — nunca há duas
--         linhas iguais em id, então a ordenação é sempre total,
--         nenhum empate chega a ser resolvido arbitrariamente pelo
--         Postgres.
-- ============================================================
CREATE TEMP TABLE "_mensalidades_rank" ON COMMIT DROP AS
SELECT
  id,
  "matriculaId",
  "dataVencimento",
  ROW_NUMBER() OVER (
    PARTITION BY "matriculaId", "dataVencimento"
    ORDER BY
      CASE status
        WHEN 'PAGA' THEN 0
        WHEN 'PENDENTE' THEN 1
        WHEN 'CANCELADA' THEN 2
      END,
      CASE WHEN "deletedAt" IS NULL THEN 0 ELSE 1 END,
      "createdAt" ASC,
      id ASC
  ) AS rn
FROM "mensalidades";

CREATE TEMP TABLE "_mensalidades_perdedoras" ON COMMIT DROP AS
SELECT id FROM "_mensalidades_rank" WHERE rn > 1;

-- 2.1) Auditoria de FKs antes de remover qualquer linha.
--      Única referência existente à tabela "mensalidades" em todo o
--      schema: lancamentos.mensalidadeId (FK "lancamentos_mensalidadeId_fkey",
--      ON DELETE SET NULL, ver migration 20260712232032_financeiro).
--      Nenhuma outra tabela referencia Mensalidade.
--      Se qualquer linha marcada para remoção estiver referenciada,
--      a premissa "PAGA nunca é removida" foi violada em algum
--      cenário não previsto — aborta a migration inteira (RAISE
--      EXCEPTION desfaz a transação por completo) em vez de deixar o
--      Postgres silenciosamente setar mensalidadeId = NULL num
--      Lancamento e órfão um pagamento.
DO $$
DECLARE
  total_referenciados integer;
BEGIN
  SELECT COUNT(*) INTO total_referenciados
  FROM "lancamentos" l
  WHERE l."mensalidadeId" IN (SELECT id FROM "_mensalidades_perdedoras");

  IF total_referenciados > 0 THEN
    RAISE EXCEPTION
      'Migration abortada: % registro(s) de Mensalidade marcado(s) para remoção por duplicidade possuem Lancamento vinculado (pagamento). Isso viola a premissa de que uma mensalidade PAGA nunca é removida — investigar manualmente antes de prosseguir. Nenhuma alteração foi persistida nesta migration.',
      total_referenciados;
  END IF;
END $$;

-- 2.2) Arquivamento — cópia integral de cada linha perdedora antes da
--      remoção. Nenhum dado é descartado: só sai da tabela
--      operacional "mensalidades" para esta tabela de histórico.
CREATE TABLE IF NOT EXISTS "mensalidades_duplicatas_removidas_20260717" (
  LIKE "mensalidades"
);

ALTER TABLE "mensalidades_duplicatas_removidas_20260717"
  ADD COLUMN IF NOT EXISTS "removidoEm" TIMESTAMP(3) NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS "motivoRemocao" TEXT NOT NULL DEFAULT 'duplicidade_matriculaId_dataVencimento_migration_20260717150000';

INSERT INTO "mensalidades_duplicatas_removidas_20260717"
  (id, "academiaId", "matriculaId", "alunoId", valor, desconto, multa,
   "dataVencimento", "dataPagamento", status, "motivoCancelamento",
   "createdByUserId", "deletedAt", "createdAt", "updatedAt")
SELECT
  m.id, m."academiaId", m."matriculaId", m."alunoId", m.valor, m.desconto, m.multa,
  m."dataVencimento", m."dataPagamento", m.status, m."motivoCancelamento",
  m."createdByUserId", m."deletedAt", m."createdAt", m."updatedAt"
FROM "mensalidades" m
WHERE m.id IN (SELECT id FROM "_mensalidades_perdedoras")
  AND NOT EXISTS (
    SELECT 1 FROM "mensalidades_duplicatas_removidas_20260717" a WHERE a.id = m.id
  );

-- 2.3) Remoção real — só os IDs já arquivados acima; nunca uma linha
--      PAGA (garantido pela ordenação em 2 + pelo gate de FK em 2.1).
DELETE FROM "mensalidades"
WHERE id IN (SELECT id FROM "_mensalidades_perdedoras");

-- 2.4) Resumo da consolidação em audit_logs, para auditorias futuras.
--      Reaproveita a action MENSALIDADE_DELETED (já existente) em vez
--      de criar um novo valor de enum — ALTER TYPE ... ADD VALUE não
--      pode ser usado na mesma transação em que o valor é consumido.
--      Só grava se algo de fato foi consolidado (idempotente: uma
--      segunda execução sem duplicados não insere linha nenhuma).
INSERT INTO "audit_logs" (id, action, metadata, "createdAt")
SELECT
  gen_random_uuid(),
  'MENSALIDADE_DELETED',
  jsonb_build_object(
    'motivo', 'consolidacao_duplicidade_migration_20260717150000',
    'gruposDuplicados', (
      SELECT COUNT(*) FROM (
        SELECT "matriculaId", "dataVencimento"
        FROM "_mensalidades_rank"
        WHERE rn > 1
        GROUP BY "matriculaId", "dataVencimento"
      ) grupos
    ),
    'registrosArquivados', (SELECT COUNT(*) FROM "_mensalidades_perdedoras"),
    'registrosRemovidos', (SELECT COUNT(*) FROM "_mensalidades_perdedoras"),
    'tabelaArquivo', 'mensalidades_duplicatas_removidas_20260717'
  ),
  now()
WHERE EXISTS (SELECT 1 FROM "_mensalidades_perdedoras");

-- ============================================================
-- 3) Índice único completo — nunca duas mensalidades pro mesmo
--    (matriculaId, dataVencimento), independente de deletedAt/status.
--    Substitui o índice plano da migration anterior (mesmo nome,
--    reconstruído aqui para o caso de ambientes onde ela já havia
--    sido aplicada com sucesso).
-- ============================================================
DROP INDEX IF EXISTS "mensalidades_matriculaId_dataVencimento_key";

CREATE UNIQUE INDEX "mensalidades_matriculaId_dataVencimento_key"
  ON "mensalidades"("matriculaId", "dataVencimento");
