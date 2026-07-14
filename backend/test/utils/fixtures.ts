import { randomUUID } from 'node:crypto';
import {
  Academia,
  Aluno,
  Matricula,
  Modalidade,
  Plano,
  Prisma,
  PrismaClient,
  Professor,
  Sexo,
} from '@prisma/client';

/// Jest roda os arquivos de e2e em workers paralelos, todos contra o mesmo
/// Postgres — Date.now() sozinho já colidiu de verdade entre processos
/// diferentes na mesma millisecond (achado real, não hipotético). UUID
/// evita a colisão sem precisar coordenar entre workers.
function unique(prefixo: string): string {
  return `${prefixo}-${randomUUID()}`;
}

/// Toda Academia precisa de um PlanoSaas (FK obrigatória) — fixture mínima
/// para testes que não estão testando o catálogo de planos em si.
export function createPlanoSaasFixture(prisma: PrismaClient, nome = unique('Fixture')) {
  return prisma.planoSaas.create({ data: { nome } });
}

export async function createAcademiaFixture(
  prisma: PrismaClient,
  overrides: Partial<Prisma.AcademiaUncheckedCreateInput> = {},
): Promise<Academia> {
  const planoSaasId = overrides.planoSaasId ?? (await createPlanoSaasFixture(prisma)).id;

  return prisma.academia.create({
    data: {
      nome: unique('Academia Fixture'),
      cnpj: unique('FIXTURE'),
      ...overrides,
      planoSaasId,
    },
  });
}

/// Aluno mínimo para testes que precisam de um aluno real (Matrícula) mas
/// não estão testando o cadastro de Aluno em si.
export function createAlunoFixture(
  prisma: PrismaClient,
  academiaId: string,
  overrides: Partial<Prisma.AlunoUncheckedCreateInput> = {},
): Promise<Aluno> {
  return prisma.aluno.create({
    data: {
      academiaId,
      nome: unique('Aluno Fixture'),
      cpf: unique('CPF'),
      dataNascimento: new Date('1995-01-01'),
      sexo: Sexo.MASCULINO,
      telefone: '11999999999',
      ...overrides,
    },
  });
}

/// Professor mínimo para testes que precisam de um professor real (Turma)
/// mas não estão testando o cadastro de Professor em si.
export function createProfessorFixture(
  prisma: PrismaClient,
  academiaId: string,
  overrides: Partial<Prisma.ProfessorUncheckedCreateInput> = {},
): Promise<Professor> {
  return prisma.professor.create({
    data: {
      academiaId,
      nome: unique('Professor Fixture'),
      cpf: unique('CPF'),
      telefone: '11999999999',
      ...overrides,
    },
  });
}

/// Modalidade mínima para testes que precisam de uma modalidade real
/// (Turma) mas não estão testando o cadastro de Modalidade em si.
export function createModalidadeFixture(
  prisma: PrismaClient,
  academiaId: string,
  overrides: Partial<Prisma.ModalidadeUncheckedCreateInput> = {},
): Promise<Modalidade> {
  return prisma.modalidade.create({
    data: {
      academiaId,
      nome: unique('Modalidade Fixture'),
      ...overrides,
    },
  });
}

/// Plano mínimo para testes que precisam de um plano real (Matrícula) mas
/// não estão testando o cadastro de Plano em si.
export function createPlanoFixture(
  prisma: PrismaClient,
  academiaId: string,
  overrides: Partial<Prisma.PlanoUncheckedCreateInput> = {},
): Promise<Plano> {
  return prisma.plano.create({
    data: {
      academiaId,
      nome: unique('Plano Fixture'),
      periodicidade: 'MENSAL',
      valor: 100,
      ...overrides,
    },
  });
}

/// Matrícula ATIVA mínima para testes de Financeiro — cria direto via
/// Prisma (não via API) porque esses testes não estão validando as regras
/// de negócio de Matrícula em si, só precisam de uma matrícula real pra
/// gerar Mensalidade. `createdByUserId` precisa de um `User` já existente
/// (normalmente o mesmo usuário logado no cenário do teste).
export function createMatriculaFixture(
  prisma: PrismaClient,
  academiaId: string,
  alunoId: string,
  planoId: string,
  createdByUserId: string,
  overrides: Partial<Prisma.MatriculaUncheckedCreateInput> = {},
): Promise<Matricula> {
  const dataInicio = new Date('2026-01-10');
  const dataFim = new Date('2026-12-10');
  return prisma.matricula.create({
    data: {
      academiaId,
      alunoId,
      planoId,
      createdByUserId,
      valor: 150,
      diaVencimento: 10,
      dataInicio,
      dataFimPrevista: dataFim,
      dataFim,
      status: 'ATIVA',
      ...overrides,
    },
  });
}
