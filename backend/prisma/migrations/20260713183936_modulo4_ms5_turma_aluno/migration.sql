-- AlterEnum
ALTER TYPE "AuditAction" ADD VALUE 'TURMA_ALUNO_STATUS_CHANGED';

-- DropIndex
DROP INDEX "turma_alunos_turmaId_alunoId_key";

-- CreateIndex
CREATE INDEX "turma_alunos_turmaId_idx" ON "turma_alunos"("turmaId");
