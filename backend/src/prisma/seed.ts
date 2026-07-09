import { PrismaClient, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

interface PlanoSaasSeed {
  nome: string;
  ordem: number;
  limiteAlunos: number | null;
  limiteProfessores: number | null;
  limiteUsuarios: number | null;
  limiteArmazenamentoMb: number | null;
  limiteBackups: number | null;
}

const PLANOS_SAAS: PlanoSaasSeed[] = [
  {
    nome: 'Free',
    ordem: 0,
    limiteAlunos: 20,
    limiteProfessores: 2,
    limiteUsuarios: 3,
    limiteArmazenamentoMb: 100,
    limiteBackups: 0,
  },
  {
    nome: 'Trial',
    ordem: 1,
    limiteAlunos: 50,
    limiteProfessores: 5,
    limiteUsuarios: 5,
    limiteArmazenamentoMb: 500,
    limiteBackups: 1,
  },
  {
    nome: 'Basic',
    ordem: 2,
    limiteAlunos: 150,
    limiteProfessores: 10,
    limiteUsuarios: 10,
    limiteArmazenamentoMb: 2000,
    limiteBackups: 7,
  },
  {
    nome: 'Professional',
    ordem: 3,
    limiteAlunos: 500,
    limiteProfessores: 30,
    limiteUsuarios: 30,
    limiteArmazenamentoMb: 10_000,
    limiteBackups: 30,
  },
  {
    nome: 'Enterprise',
    ordem: 4,
    limiteAlunos: null,
    limiteProfessores: null,
    limiteUsuarios: null,
    limiteArmazenamentoMb: null,
    limiteBackups: null,
  },
];

async function main() {
  const senhaHash = await bcrypt.hash('admin123', 10);

  const systemAdmin = await prisma.user.upsert({
    where: { email: 'admin@saasgym.com' },
    update: {},
    create: {
      nome: 'Administrador do Sistema',
      email: 'admin@saasgym.com',
      senhaHash,
      role: Role.SYSTEM_ADMIN,
    },
  });

  for (const plano of PLANOS_SAAS) {
    await prisma.planoSaas.upsert({
      where: { nome: plano.nome },
      update: plano,
      create: plano,
    });
  }

  const planoTrial = await prisma.planoSaas.findUniqueOrThrow({ where: { nome: 'Trial' } });

  const academiaDemo = await prisma.academia.upsert({
    where: { cnpj: '00000000000100' },
    update: {},
    create: {
      nome: 'Academia Demo',
      cnpj: '00000000000100',
      email: 'contato@academiademo.com',
      status: 'ATIVA',
      planoSaasId: planoTrial.id,
    },
  });

  await prisma.academiaConfiguracao.upsert({
    where: { academiaId: academiaDemo.id },
    update: {},
    create: { academiaId: academiaDemo.id },
  });

  await prisma.user.upsert({
    where: { email: 'admin@academiademo.com' },
    update: {},
    create: {
      nome: 'Admin Academia Demo',
      email: 'admin@academiademo.com',
      senhaHash,
      role: Role.ACADEMIA_ADMIN,
      academiaId: academiaDemo.id,
    },
  });

  console.log('Seed concluído:', {
    systemAdmin: systemAdmin.email,
    planosSaas: PLANOS_SAAS.map((p) => p.nome),
    academiaDemo: academiaDemo.nome,
  });
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
