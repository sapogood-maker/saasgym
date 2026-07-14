-- CreateEnum
CREATE TYPE "RecorrenciaTipo" AS ENUM ('SEMANAL', 'MENSAL', 'INTERVALADA');

-- CreateEnum
CREATE TYPE "AulaStatus" AS ENUM ('AGENDADA', 'CANCELADA');

-- CreateEnum
CREATE TYPE "AulaAlunoTipo" AS ENUM ('MATRICULADO', 'FILA_ESPERA', 'REPOSICAO');

-- CreateEnum
CREATE TYPE "PresencaStatus" AS ENUM ('PRESENTE', 'AUSENTE', 'JUSTIFICADA');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "AuditAction" ADD VALUE 'MODALIDADE_CREATED';
ALTER TYPE "AuditAction" ADD VALUE 'MODALIDADE_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE 'MODALIDADE_DELETED';
ALTER TYPE "AuditAction" ADD VALUE 'TURMA_CREATED';
ALTER TYPE "AuditAction" ADD VALUE 'TURMA_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE 'TURMA_STATUS_CHANGED';
ALTER TYPE "AuditAction" ADD VALUE 'TURMA_DELETED';
ALTER TYPE "AuditAction" ADD VALUE 'RECORRENCIA_CREATED';
ALTER TYPE "AuditAction" ADD VALUE 'RECORRENCIA_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE 'RECORRENCIA_DELETED';
ALTER TYPE "AuditAction" ADD VALUE 'AULA_GERADA';
ALTER TYPE "AuditAction" ADD VALUE 'AULA_CANCELADA';
ALTER TYPE "AuditAction" ADD VALUE 'AULA_SUBSTITUICAO';
ALTER TYPE "AuditAction" ADD VALUE 'AULA_EXTRA_CRIADA';
ALTER TYPE "AuditAction" ADD VALUE 'AULA_DELETED';
ALTER TYPE "AuditAction" ADD VALUE 'TURMA_ALUNO_MATRICULADO';
ALTER TYPE "AuditAction" ADD VALUE 'TURMA_ALUNO_REMOVIDO';
ALTER TYPE "AuditAction" ADD VALUE 'AULA_ALUNO_PRESENCA_MARCADA';
ALTER TYPE "AuditAction" ADD VALUE 'AULA_ALUNO_REPOSICAO_CRIADA';
ALTER TYPE "AuditAction" ADD VALUE 'FERIADO_CREATED';
ALTER TYPE "AuditAction" ADD VALUE 'FERIADO_DELETED';

-- CreateTable
CREATE TABLE "modalidades" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "cor" TEXT,
    "status" "UserStatus" NOT NULL DEFAULT 'ATIVO',
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "modalidades_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "turmas" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "modalidadeId" TEXT NOT NULL,
    "professorId" TEXT NOT NULL,
    "capacidadeMaxima" INTEGER,
    "local" TEXT,
    "status" "UserStatus" NOT NULL DEFAULT 'ATIVO',
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "turmas_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "recorrencias" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "turmaId" TEXT NOT NULL,
    "tipo" "RecorrenciaTipo" NOT NULL,
    "diaSemana" INTEGER,
    "diaDoMes" INTEGER,
    "intervaloDias" INTEGER,
    "horaInicio" TEXT NOT NULL,
    "duracaoMinutos" INTEGER NOT NULL,
    "professorId" TEXT,
    "dataInicioVigencia" TIMESTAMP(3) NOT NULL,
    "dataFimVigencia" TIMESTAMP(3),
    "ativo" BOOLEAN NOT NULL DEFAULT true,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "recorrencias_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "aulas" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "turmaId" TEXT NOT NULL,
    "recorrenciaId" TEXT,
    "data" TIMESTAMP(3) NOT NULL,
    "horaInicio" TEXT NOT NULL,
    "duracaoMinutos" INTEGER NOT NULL,
    "professorId" TEXT NOT NULL,
    "capacidadeMaxima" INTEGER,
    "status" "AulaStatus" NOT NULL DEFAULT 'AGENDADA',
    "motivoCancelamento" TEXT,
    "createdByUserId" TEXT NOT NULL,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "aulas_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "turma_alunos" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "turmaId" TEXT NOT NULL,
    "alunoId" TEXT NOT NULL,
    "matriculaId" TEXT NOT NULL,
    "status" "UserStatus" NOT NULL DEFAULT 'ATIVO',
    "dataInicio" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "dataFim" TIMESTAMP(3),
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "turma_alunos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "aula_alunos" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "aulaId" TEXT NOT NULL,
    "alunoId" TEXT NOT NULL,
    "turmaAlunoId" TEXT,
    "tipo" "AulaAlunoTipo" NOT NULL DEFAULT 'MATRICULADO',
    "presenca" "PresencaStatus",
    "reposicaoDeAulaAlunoId" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "aula_alunos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "feriados" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "data" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "feriados_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "modalidades_academiaId_idx" ON "modalidades"("academiaId");

-- CreateIndex
CREATE UNIQUE INDEX "modalidades_academiaId_nome_key" ON "modalidades"("academiaId", "nome");

-- CreateIndex
CREATE INDEX "turmas_academiaId_idx" ON "turmas"("academiaId");

-- CreateIndex
CREATE INDEX "turmas_modalidadeId_idx" ON "turmas"("modalidadeId");

-- CreateIndex
CREATE INDEX "turmas_professorId_idx" ON "turmas"("professorId");

-- CreateIndex
CREATE INDEX "recorrencias_academiaId_idx" ON "recorrencias"("academiaId");

-- CreateIndex
CREATE INDEX "recorrencias_turmaId_idx" ON "recorrencias"("turmaId");

-- CreateIndex
CREATE INDEX "aulas_academiaId_idx" ON "aulas"("academiaId");

-- CreateIndex
CREATE INDEX "aulas_turmaId_idx" ON "aulas"("turmaId");

-- CreateIndex
CREATE INDEX "aulas_data_idx" ON "aulas"("data");

-- CreateIndex
CREATE UNIQUE INDEX "aulas_recorrenciaId_data_key" ON "aulas"("recorrenciaId", "data");

-- CreateIndex
CREATE INDEX "turma_alunos_academiaId_idx" ON "turma_alunos"("academiaId");

-- CreateIndex
CREATE INDEX "turma_alunos_alunoId_idx" ON "turma_alunos"("alunoId");

-- CreateIndex
CREATE UNIQUE INDEX "turma_alunos_turmaId_alunoId_key" ON "turma_alunos"("turmaId", "alunoId");

-- CreateIndex
CREATE UNIQUE INDEX "aula_alunos_reposicaoDeAulaAlunoId_key" ON "aula_alunos"("reposicaoDeAulaAlunoId");

-- CreateIndex
CREATE INDEX "aula_alunos_academiaId_idx" ON "aula_alunos"("academiaId");

-- CreateIndex
CREATE INDEX "aula_alunos_aulaId_idx" ON "aula_alunos"("aulaId");

-- CreateIndex
CREATE INDEX "aula_alunos_alunoId_idx" ON "aula_alunos"("alunoId");

-- CreateIndex
CREATE UNIQUE INDEX "aula_alunos_aulaId_alunoId_key" ON "aula_alunos"("aulaId", "alunoId");

-- CreateIndex
CREATE INDEX "feriados_academiaId_idx" ON "feriados"("academiaId");

-- CreateIndex
CREATE UNIQUE INDEX "feriados_academiaId_data_key" ON "feriados"("academiaId", "data");

-- AddForeignKey
ALTER TABLE "modalidades" ADD CONSTRAINT "modalidades_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "turmas" ADD CONSTRAINT "turmas_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "turmas" ADD CONSTRAINT "turmas_modalidadeId_fkey" FOREIGN KEY ("modalidadeId") REFERENCES "modalidades"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "turmas" ADD CONSTRAINT "turmas_professorId_fkey" FOREIGN KEY ("professorId") REFERENCES "professores"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recorrencias" ADD CONSTRAINT "recorrencias_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recorrencias" ADD CONSTRAINT "recorrencias_turmaId_fkey" FOREIGN KEY ("turmaId") REFERENCES "turmas"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recorrencias" ADD CONSTRAINT "recorrencias_professorId_fkey" FOREIGN KEY ("professorId") REFERENCES "professores"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "aulas" ADD CONSTRAINT "aulas_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "aulas" ADD CONSTRAINT "aulas_turmaId_fkey" FOREIGN KEY ("turmaId") REFERENCES "turmas"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "aulas" ADD CONSTRAINT "aulas_recorrenciaId_fkey" FOREIGN KEY ("recorrenciaId") REFERENCES "recorrencias"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "aulas" ADD CONSTRAINT "aulas_professorId_fkey" FOREIGN KEY ("professorId") REFERENCES "professores"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "aulas" ADD CONSTRAINT "aulas_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "turma_alunos" ADD CONSTRAINT "turma_alunos_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "turma_alunos" ADD CONSTRAINT "turma_alunos_turmaId_fkey" FOREIGN KEY ("turmaId") REFERENCES "turmas"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "turma_alunos" ADD CONSTRAINT "turma_alunos_alunoId_fkey" FOREIGN KEY ("alunoId") REFERENCES "alunos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "turma_alunos" ADD CONSTRAINT "turma_alunos_matriculaId_fkey" FOREIGN KEY ("matriculaId") REFERENCES "matriculas"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "aula_alunos" ADD CONSTRAINT "aula_alunos_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "aula_alunos" ADD CONSTRAINT "aula_alunos_aulaId_fkey" FOREIGN KEY ("aulaId") REFERENCES "aulas"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "aula_alunos" ADD CONSTRAINT "aula_alunos_alunoId_fkey" FOREIGN KEY ("alunoId") REFERENCES "alunos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "aula_alunos" ADD CONSTRAINT "aula_alunos_turmaAlunoId_fkey" FOREIGN KEY ("turmaAlunoId") REFERENCES "turma_alunos"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "aula_alunos" ADD CONSTRAINT "aula_alunos_reposicaoDeAulaAlunoId_fkey" FOREIGN KEY ("reposicaoDeAulaAlunoId") REFERENCES "aula_alunos"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "feriados" ADD CONSTRAINT "feriados_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;
