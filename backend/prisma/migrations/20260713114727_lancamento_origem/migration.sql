-- CreateEnum
CREATE TYPE "LancamentoOrigem" AS ENUM ('MANUAL', 'MENSALIDADE');

-- AlterTable
ALTER TABLE "lancamentos" ADD COLUMN     "origem" "LancamentoOrigem" NOT NULL DEFAULT 'MANUAL';
