import { Academia, Prisma, PrismaClient } from '@prisma/client';

/// Toda Academia precisa de um PlanoSaas (FK obrigatória) — fixture mínima
/// para testes que não estão testando o catálogo de planos em si.
export function createPlanoSaasFixture(prisma: PrismaClient, nome = `Fixture-${Date.now()}`) {
  return prisma.planoSaas.create({ data: { nome } });
}

export async function createAcademiaFixture(
  prisma: PrismaClient,
  overrides: Partial<Prisma.AcademiaUncheckedCreateInput> = {},
): Promise<Academia> {
  const planoSaasId = overrides.planoSaasId ?? (await createPlanoSaasFixture(prisma)).id;

  return prisma.academia.create({
    data: {
      nome: `Academia Fixture ${Date.now()}`,
      cnpj: `FIXTURE-${Date.now()}`,
      ...overrides,
      planoSaasId,
    },
  });
}
