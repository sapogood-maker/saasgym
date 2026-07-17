-- Sprint de Integridade Financeira (docs/29-auditoria-financeiro-estrutural.md)
--
-- 1) Matricula.periodicidade — snapshot de Plano.periodicidade no momento da
--    criação/renovação. Adicionada nullable primeiro porque a tabela já tem
--    linhas (dado real de dev/teste); backfill abaixo usa a periodicidade
--    ATUAL do Plano vinculado como melhor aproximação disponível para
--    matrículas anteriores a esta migration (não recupera a periodicidade
--    histórica se o Plano já mudou desde a criação da matrícula — essa
--    informação nunca foi capturada antes desta migration).
ALTER TABLE "matriculas" ADD COLUMN "periodicidade" "Periodicidade";

UPDATE "matriculas" m
SET "periodicidade" = p."periodicidade"
FROM "planos" p
WHERE m."planoId" = p."id";

ALTER TABLE "matriculas" ALTER COLUMN "periodicidade" SET NOT NULL;

-- 2) Mensalidade: nunca duas cobranças para o mesmo (matriculaId,
--    dataVencimento) — proteção de banco complementar à checagem já
--    existente em MensalidadesService.gerar() e à nova geração automática
--    em MatriculasService (createMany + skipDuplicates).
CREATE UNIQUE INDEX "mensalidades_matriculaId_dataVencimento_key" ON "mensalidades"("matriculaId", "dataVencimento");
