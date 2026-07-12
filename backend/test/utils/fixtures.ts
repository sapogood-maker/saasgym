import { randomUUID } from 'node:crypto';
import { Academia, Aluno, Plano, Prisma, PrismaClient, Sexo } from '@prisma/client';

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
