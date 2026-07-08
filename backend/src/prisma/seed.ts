import { PrismaClient, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

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

  const academiaDemo = await prisma.academia.upsert({
    where: { cnpj: '00000000000100' },
    update: {},
    create: {
      nome: 'Academia Demo',
      cnpj: '00000000000100',
      email: 'contato@academiademo.com',
      status: 'ATIVA',
    },
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
