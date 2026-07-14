import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import {
  createAcademiaFixture,
  createAlunoFixture,
  createMatriculaFixture,
  createPlanoFixture,
} from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

const SENHA = 'SenhaForte123';

describe('Dashboard Financeiro (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string) {
    const email = `${role.toLowerCase()}-dashboard-${Date.now()}-${Math.random()}@example.com`;
    const user = await prisma.user.create({
      data: {
        nome: `Usuário ${role}`,
        email,
        senhaHash: await bcrypt.hash(SENHA, 10),
        role,
        academiaId,
      },
    });
    const res = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email, password: SENHA })
      .expect(200);
    return { token: res.body.accessToken as string, userId: user.id };
  }

  async function cenarioBase(nomeAcademia: string) {
    const academia = await createAcademiaFixture(prisma, { nome: nomeAcademia });
    const { token, userId } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    return { academia, token, userId };
  }

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('sem token -> 401', async () => {
    await request(app.getHttpServer()).get('/api/financeiro/dashboard').expect(401);
  });

  it('PROFESSOR não tem acesso (403)', async () => {
    const academia = await createAcademiaFixture(prisma, {
      nome: 'Academia Professor Sem Acesso Dashboard E2E',
    });
    const { token } = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    await request(app.getHttpServer())
      .get('/api/financeiro/dashboard')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  describe('Resumo (KPIs do mês)', () => {
    it('agrega receita prevista, recebida, despesas, saldo e inadimplência', async () => {
      const { academia, token, userId } = await cenarioBase('Academia Dashboard Resumo E2E');
      const aluno = await createAlunoFixture(prisma, academia.id);
      const plano = await createPlanoFixture(prisma, academia.id, { valor: 200 });
      const matricula = await createMatriculaFixture(prisma, academia.id, aluno.id, plano.id, userId, {
        valor: 200,
      });

      await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'RECEITA', descricao: 'Venda avulsa', valor: 80, data: '2026-07-10' })
        .expect(201);
      await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'DESPESA', descricao: 'Aluguel', valor: 50, data: '2026-07-15' })
        .expect(201);

      // inadimplente: PENDENTE, vencida bem no passado (independe de quando o teste roda)
      await prisma.mensalidade.create({
        data: {
          academiaId: academia.id,
          matriculaId: matricula.id,
          alunoId: aluno.id,
          valor: 150,
          dataVencimento: new Date('2020-01-10'),
          status: 'PENDENTE',
          createdByUserId: userId,
        },
      });

      const resumo = await request(app.getHttpServer())
        .get('/api/financeiro/dashboard?mes=7&ano=2026')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(resumo.body.mes).toBe(7);
      expect(resumo.body.ano).toBe(2026);
      expect(resumo.body.receitaPrevista).toBe(200);
      expect(resumo.body.receitaRecebida).toBe(80);
      expect(resumo.body.despesas).toBe(50);
      expect(resumo.body.saldo).toBe(30);
      expect(resumo.body.inadimplenciaValor).toBe(150);
      expect(resumo.body.inadimplenciaQuantidade).toBe(1);
    });

    it('mensalidade PENDENTE com vencimento futuro não conta como inadimplência', async () => {
      const { academia, token, userId } = await cenarioBase('Academia Dashboard Sem Inadimplencia E2E');
      const aluno = await createAlunoFixture(prisma, academia.id);
      const plano = await createPlanoFixture(prisma, academia.id, { valor: 100 });
      const matricula = await createMatriculaFixture(prisma, academia.id, aluno.id, plano.id, userId);

      await prisma.mensalidade.create({
        data: {
          academiaId: academia.id,
          matriculaId: matricula.id,
          alunoId: aluno.id,
          valor: 100,
          dataVencimento: new Date('2030-01-10'),
          status: 'PENDENTE',
          createdByUserId: userId,
        },
      });

      const resumo = await request(app.getHttpServer())
        .get('/api/financeiro/dashboard?mes=7&ano=2026')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(resumo.body.inadimplenciaValor).toBe(0);
      expect(resumo.body.inadimplenciaQuantidade).toBe(0);
    });

    it('mensalidade PAGA vencida não conta como inadimplência', async () => {
      const { academia, token, userId } = await cenarioBase('Academia Dashboard Paga Nao Conta E2E');
      const aluno = await createAlunoFixture(prisma, academia.id);
      const plano = await createPlanoFixture(prisma, academia.id, { valor: 100 });
      const matricula = await createMatriculaFixture(prisma, academia.id, aluno.id, plano.id, userId);

      await prisma.mensalidade.create({
        data: {
          academiaId: academia.id,
          matriculaId: matricula.id,
          alunoId: aluno.id,
          valor: 100,
          dataVencimento: new Date('2020-01-10'),
          status: 'PAGA',
          createdByUserId: userId,
        },
      });

      const resumo = await request(app.getHttpServer())
        .get('/api/financeiro/dashboard?mes=7&ano=2026')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(resumo.body.inadimplenciaValor).toBe(0);
      expect(resumo.body.inadimplenciaQuantidade).toBe(0);
    });

    it('mês sem nenhum dado retorna tudo zerado', async () => {
      const { token } = await cenarioBase('Academia Dashboard Vazio E2E');

      const resumo = await request(app.getHttpServer())
        .get('/api/financeiro/dashboard?mes=1&ano=2020')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(resumo.body).toMatchObject({
        receitaPrevista: 0,
        receitaRecebida: 0,
        despesas: 0,
        saldo: 0,
        inadimplenciaValor: 0,
        inadimplenciaQuantidade: 0,
      });
    });

    it('usa mês/ano corrente quando não informado', async () => {
      const { academia, token, userId } = await cenarioBase('Academia Dashboard Default Mes E2E');
      const aluno = await createAlunoFixture(prisma, academia.id);
      const plano = await createPlanoFixture(prisma, academia.id, { valor: 77 });
      const agora = new Date();
      await createMatriculaFixture(prisma, academia.id, aluno.id, plano.id, userId, {
        valor: 77,
        dataInicio: new Date(Date.UTC(agora.getUTCFullYear() - 1, 0, 1)),
        dataFimPrevista: new Date(Date.UTC(agora.getUTCFullYear() + 1, 11, 31)),
        dataFim: new Date(Date.UTC(agora.getUTCFullYear() + 1, 11, 31)),
      });

      const resumo = await request(app.getHttpServer())
        .get('/api/financeiro/dashboard')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(resumo.body.mes).toBe(agora.getUTCMonth() + 1);
      expect(resumo.body.ano).toBe(agora.getUTCFullYear());
      expect(resumo.body.receitaPrevista).toBe(77);
    });

    it('isola por tenant', async () => {
      const cenarioA = await cenarioBase('Academia Dashboard Isolamento A E2E');
      const cenarioB = await cenarioBase('Academia Dashboard Isolamento B E2E');
      const alunoB = await createAlunoFixture(prisma, cenarioB.academia.id);
      const planoB = await createPlanoFixture(prisma, cenarioB.academia.id, { valor: 999 });
      await createMatriculaFixture(prisma, cenarioB.academia.id, alunoB.id, planoB.id, cenarioB.userId, {
        valor: 999,
      });

      const resumoA = await request(app.getHttpServer())
        .get('/api/financeiro/dashboard?mes=7&ano=2026')
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(200);

      expect(resumoA.body.receitaPrevista).toBe(0);
    });
  });

  describe('Evolução mensal', () => {
    it('retorna a janela de meses (default 6), mais recente primeiro, com receita prevista/recebida/despesas/saldo por mês', async () => {
      const { academia, token, userId } = await cenarioBase('Academia Dashboard Evolucao E2E');
      const aluno = await createAlunoFixture(prisma, academia.id);
      const plano = await createPlanoFixture(prisma, academia.id, { valor: 100 });
      await createMatriculaFixture(prisma, academia.id, aluno.id, plano.id, userId, {
        valor: 100,
        dataInicio: new Date('2026-01-01'),
        dataFimPrevista: new Date('2026-12-31'),
        dataFim: new Date('2026-12-31'),
      });

      await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'RECEITA', descricao: 'Recebido em maio', valor: 40, data: '2026-05-10' })
        .expect(201);
      await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'RECEITA', descricao: 'Recebido em julho', valor: 60, data: '2026-07-10' })
        .expect(201);

      const evolucao = await request(app.getHttpServer())
        .get('/api/financeiro/dashboard/evolucao?mes=7&ano=2026')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(evolucao.body.meses).toHaveLength(6);
      expect(evolucao.body.meses[0]).toMatchObject({
        mes: 7,
        ano: 2026,
        receitaPrevista: 100,
        receitaRecebida: 60,
      });
      expect(evolucao.body.meses[1]).toMatchObject({
        mes: 6,
        ano: 2026,
        receitaPrevista: 100,
        receitaRecebida: 0,
      });
      expect(evolucao.body.meses[2]).toMatchObject({
        mes: 5,
        ano: 2026,
        receitaPrevista: 100,
        receitaRecebida: 40,
      });
      expect(evolucao.body.meses[5]).toMatchObject({ mes: 2, ano: 2026 });
    });

    it('respeita o parâmetro meses (janela customizada)', async () => {
      const { token } = await cenarioBase('Academia Dashboard Evolucao Custom E2E');

      const evolucao = await request(app.getHttpServer())
        .get('/api/financeiro/dashboard/evolucao?mes=7&ano=2026&meses=2')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(evolucao.body.meses).toHaveLength(2);
      expect(evolucao.body.meses[0]).toMatchObject({ mes: 7, ano: 2026 });
      expect(evolucao.body.meses[1]).toMatchObject({ mes: 6, ano: 2026 });
    });

    it('vira o ano corretamente quando a janela cruza janeiro', async () => {
      const { token } = await cenarioBase('Academia Dashboard Evolucao Vira Ano E2E');

      const evolucao = await request(app.getHttpServer())
        .get('/api/financeiro/dashboard/evolucao?mes=2&ano=2026&meses=4')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(evolucao.body.meses).toEqual([
        expect.objectContaining({ mes: 2, ano: 2026 }),
        expect.objectContaining({ mes: 1, ano: 2026 }),
        expect.objectContaining({ mes: 12, ano: 2025 }),
        expect.objectContaining({ mes: 11, ano: 2025 }),
      ]);
    });

    it('isola por tenant', async () => {
      const cenarioA = await cenarioBase('Academia Dashboard Evolucao Isolamento A E2E');
      const cenarioB = await cenarioBase('Academia Dashboard Evolucao Isolamento B E2E');
      const alunoB = await createAlunoFixture(prisma, cenarioB.academia.id);
      const planoB = await createPlanoFixture(prisma, cenarioB.academia.id, { valor: 500 });
      await createMatriculaFixture(prisma, cenarioB.academia.id, alunoB.id, planoB.id, cenarioB.userId, {
        valor: 500,
      });

      const evolucaoA = await request(app.getHttpServer())
        .get('/api/financeiro/dashboard/evolucao?mes=7&ano=2026&meses=1')
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(200);

      expect(evolucaoA.body.meses[0].receitaPrevista).toBe(0);
    });
  });
});
