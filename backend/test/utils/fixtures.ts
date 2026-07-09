import { randomUUID } from 'node:crypto';
import { Academia, Prisma, PrismaClient } from '@prisma/client';

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
