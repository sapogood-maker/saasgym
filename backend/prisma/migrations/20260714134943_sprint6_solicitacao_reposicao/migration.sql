-- CreateEnum
CREATE TYPE "SolicitacaoReposicaoStatus" AS ENUM ('PENDENTE', 'APROVADA', 'REJEITADA');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "AuditAction" ADD VALUE 'SOLICITACAO_REPOSICAO_CRIADA';
ALTER TYPE "AuditAction" ADD VALUE 'SOLICITACAO_REPOSICAO_APROVADA';
ALTER TYPE "AuditAction" ADD VALUE 'SOLICITACAO_REPOSICAO_REJEITADA';

-- CreateTable
CREATE TABLE "solicitacoes_reposicao" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "alunoId" TEXT NOT NULL,
    "aulaAlunoOrigemId" TEXT NOT NULL,
    "aulaDestinoId" TEXT,
    "aulaAlunoReposicaoId" TEXT,
    "status" "SolicitacaoReposicaoStatus" NOT NULL DEFAULT 'PENDENTE',
    "observacoes" TEXT,
    "motivoRejeicao" TEXT,
    "createdByUserId" TEXT NOT NULL,
    "decidedByUserId" TEXT,
    "decidedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "solicitacoes_reposicao_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "solicitacoes_reposicao_aulaAlunoReposicaoId_key" ON "solicitacoes_reposicao"("aulaAlunoReposicaoId");

-- CreateIndex
CREATE INDEX "solicitacoes_reposicao_academiaId_alunoId_idx" ON "solicitacoes_reposicao"("academiaId", "alunoId");

-- CreateIndex
CREATE INDEX "solicitacoes_reposicao_academiaId_status_idx" ON "solicitacoes_reposicao"("academiaId", "status");

-- AddForeignKey
ALTER TABLE "solicitacoes_reposicao" ADD CONSTRAINT "solicitacoes_reposicao_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "solicitacoes_reposicao" ADD CONSTRAINT "solicitacoes_reposicao_alunoId_fkey" FOREIGN KEY ("alunoId") REFERENCES "alunos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "solicitacoes_reposicao" ADD CONSTRAINT "solicitacoes_reposicao_aulaAlunoOrigemId_fkey" FOREIGN KEY ("aulaAlunoOrigemId") REFERENCES "aula_alunos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "solicitacoes_reposicao" ADD CONSTRAINT "solicitacoes_reposicao_aulaDestinoId_fkey" FOREIGN KEY ("aulaDestinoId") REFERENCES "aulas"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "solicitacoes_reposicao" ADD CONSTRAINT "solicitacoes_reposicao_aulaAlunoReposicaoId_fkey" FOREIGN KEY ("aulaAlunoReposicaoId") REFERENCES "aula_alunos"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "solicitacoes_reposicao" ADD CONSTRAINT "solicitacoes_reposicao_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "solicitacoes_reposicao" ADD CONSTRAINT "solicitacoes_reposicao_decidedByUserId_fkey" FOREIGN KEY ("decidedByUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
