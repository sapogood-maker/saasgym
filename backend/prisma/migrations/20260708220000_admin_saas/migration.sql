-- CreateEnum
CREATE TYPE "ArquivoCategoria" AS ENUM ('ACADEMIA_LOGO');

-- AlterEnum (adiciona valores, nenhum removido)
ALTER TYPE "AuditAction" ADD VALUE 'ACADEMIA_CREATED';
ALTER TYPE "AuditAction" ADD VALUE 'ACADEMIA_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE 'ACADEMIA_STATUS_CHANGED';
ALTER TYPE "AuditAction" ADD VALUE 'ACADEMIA_CONFIGURACAO_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE 'PLANO_SAAS_CREATED';
ALTER TYPE "AuditAction" ADD VALUE 'PLANO_SAAS_UPDATED';

-- AlterEnum (remove INATIVA, adiciona SUSPENSA/BLOQUEADA/CANCELADA — nenhuma
-- linha existente usa INATIVA, então o cast direto é seguro)
BEGIN;
CREATE TYPE "AcademiaStatus_new" AS ENUM ('TRIAL', 'ATIVA', 'SUSPENSA', 'BLOQUEADA', 'CANCELADA');
ALTER TABLE "academias" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "academias" ALTER COLUMN "status" TYPE "AcademiaStatus_new" USING ("status"::text::"AcademiaStatus_new");
ALTER TYPE "AcademiaStatus" RENAME TO "AcademiaStatus_old";
ALTER TYPE "AcademiaStatus_new" RENAME TO "AcademiaStatus";
DROP TYPE "AcademiaStatus_old";
ALTER TABLE "academias" ALTER COLUMN "status" SET DEFAULT 'TRIAL';
COMMIT;

-- CreateTable
CREATE TABLE "planos_saas" (
    "id" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "ativo" BOOLEAN NOT NULL DEFAULT true,
    "ordem" INTEGER,
    "limiteAlunos" INTEGER,
    "limiteProfessores" INTEGER,
    "limiteUsuarios" INTEGER,
    "limiteArmazenamentoMb" INTEGER,
    "limiteBackups" INTEGER,
    "funcionalidades" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "planos_saas_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "planos_saas_nome_key" ON "planos_saas"("nome");

-- Bootstrap: plano padrão usado só para preencher academias já existentes
-- antes da coluna academias.planoSaasId virar NOT NULL (ver seed.ts para o
-- catálogo real de planos criado depois, via aplicação).
INSERT INTO "planos_saas" ("id", "nome", "ativo", "ordem", "createdAt", "updatedAt")
VALUES ('00000000-0000-0000-0000-000000000001', 'Trial', true, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- AlterTable
ALTER TABLE "academias" ADD COLUMN "dominio" TEXT;
ALTER TABLE "academias" ADD COLUMN "trialExpiresAt" TIMESTAMP(3);
ALTER TABLE "academias" ADD COLUMN "planoSaasId" TEXT;
ALTER TABLE "academias" DROP COLUMN "logoUrl";

-- Backfill: academias criadas antes desta migration recebem o plano padrão.
UPDATE "academias" SET "planoSaasId" = '00000000-0000-0000-0000-000000000001' WHERE "planoSaasId" IS NULL;

ALTER TABLE "academias" ALTER COLUMN "planoSaasId" SET NOT NULL;

-- CreateIndex
CREATE UNIQUE INDEX "academias_dominio_key" ON "academias"("dominio");

-- AddForeignKey
ALTER TABLE "academias" ADD CONSTRAINT "academias_planoSaasId_fkey" FOREIGN KEY ("planoSaasId") REFERENCES "planos_saas"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "arquivos" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT,
    "categoria" "ArquivoCategoria" NOT NULL,
    "nomeOriginal" TEXT NOT NULL,
    "nomeArmazenado" TEXT NOT NULL,
    "caminho" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL,
    "tamanhoBytes" INTEGER NOT NULL,
    "provider" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "arquivos_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "arquivos_academiaId_idx" ON "arquivos"("academiaId");

-- CreateTable
CREATE TABLE "academia_configuracoes" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "logoArquivoId" TEXT,
    "temaCores" JSONB,
    "whatsapp" TEXT,
    "instagram" TEXT,
    "facebook" TEXT,
    "pix" TEXT,
    "horarioFuncionamento" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "academia_configuracoes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "academia_configuracoes_academiaId_key" ON "academia_configuracoes"("academiaId");

-- CreateIndex
CREATE UNIQUE INDEX "academia_configuracoes_logoArquivoId_key" ON "academia_configuracoes"("logoArquivoId");

-- AddForeignKey
ALTER TABLE "academia_configuracoes" ADD CONSTRAINT "academia_configuracoes_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "academia_configuracoes" ADD CONSTRAINT "academia_configuracoes_logoArquivoId_fkey" FOREIGN KEY ("logoArquivoId") REFERENCES "arquivos"("id") ON DELETE SET NULL ON UPDATE CASCADE;
