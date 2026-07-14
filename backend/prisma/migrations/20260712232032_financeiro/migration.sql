-- CreateEnum
CREATE TYPE "MensalidadeStatus" AS ENUM ('PENDENTE', 'PAGA', 'CANCELADA');

-- CreateEnum
CREATE TYPE "FormaPagamento" AS ENUM ('DINHEIRO', 'PIX', 'CARTAO_CREDITO', 'CARTAO_DEBITO', 'BOLETO', 'OUTRO');

-- CreateEnum
CREATE TYPE "LancamentoTipo" AS ENUM ('RECEITA', 'DESPESA');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "AuditAction" ADD VALUE 'MENSALIDADE_GERADA';
ALTER TYPE "AuditAction" ADD VALUE 'MENSALIDADE_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE 'MENSALIDADE_PAGA';
ALTER TYPE "AuditAction" ADD VALUE 'MENSALIDADE_CANCELADA';
ALTER TYPE "AuditAction" ADD VALUE 'MENSALIDADE_DELETED';
ALTER TYPE "AuditAction" ADD VALUE 'LANCAMENTO_CREATED';
ALTER TYPE "AuditAction" ADD VALUE 'LANCAMENTO_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE 'LANCAMENTO_DELETED';

-- CreateTable
CREATE TABLE "mensalidades" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "matriculaId" TEXT NOT NULL,
    "alunoId" TEXT NOT NULL,
    "valor" DECIMAL(10,2) NOT NULL,
    "desconto" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "multa" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "dataVencimento" TIMESTAMP(3) NOT NULL,
    "dataPagamento" TIMESTAMP(3),
    "status" "MensalidadeStatus" NOT NULL DEFAULT 'PENDENTE',
    "motivoCancelamento" TEXT,
    "createdByUserId" TEXT NOT NULL,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "mensalidades_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "lancamentos" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "tipo" "LancamentoTipo" NOT NULL,
    "descricao" TEXT NOT NULL,
    "categoria" TEXT,
    "valor" DECIMAL(10,2) NOT NULL,
    "data" TIMESTAMP(3) NOT NULL,
    "formaPagamento" "FormaPagamento",
    "mensalidadeId" TEXT,
    "createdByUserId" TEXT NOT NULL,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "lancamentos_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "mensalidades_academiaId_idx" ON "mensalidades"("academiaId");

-- CreateIndex
CREATE INDEX "mensalidades_matriculaId_idx" ON "mensalidades"("matriculaId");

-- CreateIndex
CREATE INDEX "mensalidades_alunoId_idx" ON "mensalidades"("alunoId");

-- CreateIndex
CREATE INDEX "mensalidades_dataVencimento_idx" ON "mensalidades"("dataVencimento");

-- CreateIndex
CREATE UNIQUE INDEX "lancamentos_mensalidadeId_key" ON "lancamentos"("mensalidadeId");

-- CreateIndex
CREATE INDEX "lancamentos_academiaId_idx" ON "lancamentos"("academiaId");

-- CreateIndex
CREATE INDEX "lancamentos_mensalidadeId_idx" ON "lancamentos"("mensalidadeId");

-- CreateIndex
CREATE INDEX "lancamentos_data_idx" ON "lancamentos"("data");

-- AddForeignKey
ALTER TABLE "mensalidades" ADD CONSTRAINT "mensalidades_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mensalidades" ADD CONSTRAINT "mensalidades_matriculaId_fkey" FOREIGN KEY ("matriculaId") REFERENCES "matriculas"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mensalidades" ADD CONSTRAINT "mensalidades_alunoId_fkey" FOREIGN KEY ("alunoId") REFERENCES "alunos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mensalidades" ADD CONSTRAINT "mensalidades_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "lancamentos" ADD CONSTRAINT "lancamentos_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "lancamentos" ADD CONSTRAINT "lancamentos_mensalidadeId_fkey" FOREIGN KEY ("mensalidadeId") REFERENCES "mensalidades"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "lancamentos" ADD CONSTRAINT "lancamentos_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
