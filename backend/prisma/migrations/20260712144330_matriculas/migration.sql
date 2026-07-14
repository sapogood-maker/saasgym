-- CreateEnum
CREATE TYPE "MatriculaStatus" AS ENUM ('ATIVA', 'TRANCADA', 'CANCELADA', 'ENCERRADA');

-- CreateEnum
CREATE TYPE "MotivoCancelamento" AS ENUM ('ALUNO_SOLICITOU', 'INADIMPLENCIA', 'ACADEMIA_CANCELOU', 'OUTRO');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "AuditAction" ADD VALUE 'MATRICULA_CREATED';
ALTER TYPE "AuditAction" ADD VALUE 'MATRICULA_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE 'MATRICULA_STATUS_CHANGED';
ALTER TYPE "AuditAction" ADD VALUE 'MATRICULA_DELETED';

-- CreateTable
CREATE TABLE "matriculas" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "alunoId" TEXT NOT NULL,
    "planoId" TEXT NOT NULL,
    "createdByUserId" TEXT NOT NULL,
    "valor" DECIMAL(10,2) NOT NULL,
    "diaVencimento" INTEGER NOT NULL,
    "dataInicio" TIMESTAMP(3) NOT NULL,
    "dataFimPrevista" TIMESTAMP(3) NOT NULL,
    "dataFim" TIMESTAMP(3) NOT NULL,
    "status" "MatriculaStatus" NOT NULL DEFAULT 'ATIVA',
    "trancadoEm" TIMESTAMP(3),
    "trancamentoMotivo" TEXT,
    "motivoCancelamento" "MotivoCancelamento",
    "motivoCancelamentoDetalhe" TEXT,
    "matriculaAnteriorId" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "matriculas_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "matriculas_matriculaAnteriorId_key" ON "matriculas"("matriculaAnteriorId");

-- CreateIndex
CREATE INDEX "matriculas_academiaId_idx" ON "matriculas"("academiaId");

-- CreateIndex
CREATE INDEX "matriculas_alunoId_idx" ON "matriculas"("alunoId");

-- CreateIndex
CREATE INDEX "matriculas_planoId_idx" ON "matriculas"("planoId");

-- AddForeignKey
ALTER TABLE "matriculas" ADD CONSTRAINT "matriculas_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "matriculas" ADD CONSTRAINT "matriculas_alunoId_fkey" FOREIGN KEY ("alunoId") REFERENCES "alunos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "matriculas" ADD CONSTRAINT "matriculas_planoId_fkey" FOREIGN KEY ("planoId") REFERENCES "planos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "matriculas" ADD CONSTRAINT "matriculas_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "matriculas" ADD CONSTRAINT "matriculas_matriculaAnteriorId_fkey" FOREIGN KEY ("matriculaAnteriorId") REFERENCES "matriculas"("id") ON DELETE SET NULL ON UPDATE CASCADE;
