-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "AuditAction" ADD VALUE 'AVALIACAO_FISICA_CREATED';
ALTER TYPE "AuditAction" ADD VALUE 'AVALIACAO_FISICA_DELETED';

-- CreateTable
CREATE TABLE "avaliacoes_fisicas" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "alunoId" TEXT NOT NULL,
    "data" TIMESTAMP(3) NOT NULL,
    "peso" DECIMAL(5,2) NOT NULL,
    "altura" DECIMAL(5,2) NOT NULL,
    "observacoes" TEXT,
    "createdByUserId" TEXT NOT NULL,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "avaliacoes_fisicas_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "avaliacoes_fisicas_academiaId_alunoId_idx" ON "avaliacoes_fisicas"("academiaId", "alunoId");

-- AddForeignKey
ALTER TABLE "avaliacoes_fisicas" ADD CONSTRAINT "avaliacoes_fisicas_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "avaliacoes_fisicas" ADD CONSTRAINT "avaliacoes_fisicas_alunoId_fkey" FOREIGN KEY ("alunoId") REFERENCES "alunos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "avaliacoes_fisicas" ADD CONSTRAINT "avaliacoes_fisicas_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
