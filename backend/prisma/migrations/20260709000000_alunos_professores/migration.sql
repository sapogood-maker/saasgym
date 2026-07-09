-- CreateEnum
CREATE TYPE "Sexo" AS ENUM ('MASCULINO', 'FEMININO', 'OUTRO');

-- AlterEnum (adiciona valores, nenhum removido)
ALTER TYPE "ArquivoCategoria" ADD VALUE 'ALUNO_FOTO';
ALTER TYPE "ArquivoCategoria" ADD VALUE 'PROFESSOR_FOTO';
ALTER TYPE "ArquivoCategoria" ADD VALUE 'USER_AVATAR';

-- AlterEnum (adiciona valores, nenhum removido)
ALTER TYPE "AuditAction" ADD VALUE 'ALUNO_CREATED';
ALTER TYPE "AuditAction" ADD VALUE 'ALUNO_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE 'ALUNO_STATUS_CHANGED';
ALTER TYPE "AuditAction" ADD VALUE 'ALUNO_DELETED';
ALTER TYPE "AuditAction" ADD VALUE 'PROFESSOR_CREATED';
ALTER TYPE "AuditAction" ADD VALUE 'PROFESSOR_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE 'PROFESSOR_STATUS_CHANGED';
ALTER TYPE "AuditAction" ADD VALUE 'PROFESSOR_DELETED';
ALTER TYPE "AuditAction" ADD VALUE 'USER_PROFILE_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE 'FOTO_UPLOADED';

-- AlterTable
ALTER TABLE "users" ADD COLUMN "fotoArquivoId" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "users_fotoArquivoId_key" ON "users"("fotoArquivoId");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_fotoArquivoId_fkey" FOREIGN KEY ("fotoArquivoId") REFERENCES "arquivos"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "alunos" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "fotoArquivoId" TEXT,
    "nome" TEXT NOT NULL,
    "cpf" TEXT NOT NULL,
    "rg" TEXT,
    "dataNascimento" TIMESTAMP(3) NOT NULL,
    "sexo" "Sexo" NOT NULL,
    "telefone" TEXT NOT NULL,
    "whatsapp" TEXT,
    "email" TEXT,
    "endereco" TEXT,
    "cidade" TEXT,
    "estado" TEXT,
    "cep" TEXT,
    "observacoes" TEXT,
    "status" "UserStatus" NOT NULL DEFAULT 'ATIVO',
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "alunos_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "alunos_fotoArquivoId_key" ON "alunos"("fotoArquivoId");

-- CreateIndex
CREATE UNIQUE INDEX "alunos_academiaId_cpf_key" ON "alunos"("academiaId", "cpf");

-- CreateIndex
CREATE INDEX "alunos_academiaId_idx" ON "alunos"("academiaId");

-- AddForeignKey
ALTER TABLE "alunos" ADD CONSTRAINT "alunos_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "alunos" ADD CONSTRAINT "alunos_fotoArquivoId_fkey" FOREIGN KEY ("fotoArquivoId") REFERENCES "arquivos"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "professores" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "fotoArquivoId" TEXT,
    "nome" TEXT NOT NULL,
    "cpf" TEXT NOT NULL,
    "telefone" TEXT NOT NULL,
    "email" TEXT,
    "especialidade" TEXT,
    "observacoes" TEXT,
    "status" "UserStatus" NOT NULL DEFAULT 'ATIVO',
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "professores_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "professores_fotoArquivoId_key" ON "professores"("fotoArquivoId");

-- CreateIndex
CREATE UNIQUE INDEX "professores_academiaId_cpf_key" ON "professores"("academiaId", "cpf");

-- CreateIndex
CREATE INDEX "professores_academiaId_idx" ON "professores"("academiaId");

-- AddForeignKey
ALTER TABLE "professores" ADD CONSTRAINT "professores_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "professores" ADD CONSTRAINT "professores_fotoArquivoId_fkey" FOREIGN KEY ("fotoArquivoId") REFERENCES "arquivos"("id") ON DELETE SET NULL ON UPDATE CASCADE;
