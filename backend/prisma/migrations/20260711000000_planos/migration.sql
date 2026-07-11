-- CreateEnum
CREATE TYPE "Periodicidade" AS ENUM ('MENSAL', 'TRIMESTRAL', 'SEMESTRAL', 'ANUAL');

-- AlterEnum (adiciona valores, nenhum removido)
ALTER TYPE "AuditAction" ADD VALUE 'PLANO_CREATED';
ALTER TYPE "AuditAction" ADD VALUE 'PLANO_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE 'PLANO_STATUS_CHANGED';
ALTER TYPE "AuditAction" ADD VALUE 'PLANO_DELETED';

-- CreateTable
CREATE TABLE "planos" (
    "id" TEXT NOT NULL,
    "academiaId" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "descricao" TEXT,
    "periodicidade" "Periodicidade" NOT NULL,
    "valor" DECIMAL(10,2) NOT NULL,
    "quantidadeAulas" INTEGER,
    "ordem" INTEGER,
    "status" "UserStatus" NOT NULL DEFAULT 'ATIVO',
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "planos_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "planos_academiaId_nome_key" ON "planos"("academiaId", "nome");

-- CreateIndex
CREATE INDEX "planos_academiaId_idx" ON "planos"("academiaId");

-- AddForeignKey
ALTER TABLE "planos" ADD CONSTRAINT "planos_academiaId_fkey" FOREIGN KEY ("academiaId") REFERENCES "academias"("id") ON DELETE CASCADE ON UPDATE CASCADE;
