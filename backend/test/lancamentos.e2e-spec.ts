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

describe('Lançamentos (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string) {
    const email = `${role.toLowerCase()}-lancamentos-${Date.now()}-${Math.random()}@example.com`;
    await prisma.user.create({
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
    return res.body.accessToken as string;
  }

  async function cenarioBase(nomeAcademia: string) {
    const academia = await createAcademiaFixture(prisma, { nome: nomeAcademia });
    const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    return { academia, token };
  }

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('sem token -> 401', async () => {
    await request(app.getHttpServer()).get('/api/financeiro/lancamentos').expect(401);
  });

  it('PROFESSOR não tem acesso (403)', async () => {
    const academia = await createAcademiaFixture(prisma, {
      nome: 'Academia Professor Sem Acesso Lancamento',
    });
    const token = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    await request(app.getHttpServer())
      .get('/api/financeiro/lancamentos')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  describe('CRUD', () => {
    it('ACADEMIA_ADMIN cria, lista, detalha, edita e remove uma despesa manual', async () => {
      const { token } = await cenarioBase('Academia CRUD Lancamento E2E');

      const criado = await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${token}`)
        .send({
          tipo: 'DESPESA',
          descricao: 'Conta de luz',
          categoria: 'Utilidades',
          valor: 320.5,
          data: '2026-07-05',
        })
        .expect(201);

      expect(criado.body.tipo).toBe('DESPESA');
      expect(criado.body.origem).toBe('MANUAL');
      expect(criado.body.valor).toBe(320.5);
      expect(typeof criado.body.valor).toBe('number');
      expect(criado.body.mensalidadeId).toBeNull();
      expect(criado.body.alunoNome).toBeNull();
      expect(criado.body.mensalidadeDataVencimento).toBeNull();

      const detalhe = await request(app.getHttpServer())
        .get(`/api/financeiro/lancamentos/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(detalhe.body.descricao).toBe('Conta de luz');

      const editado = await request(app.getHttpServer())
        .patch(`/api/financeiro/lancamentos/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ valor: 350 })
        .expect(200);
      expect(editado.body.valor).toBe(350);

      const lista = await request(app.getHttpServer())
        .get('/api/financeiro/lancamentos?tipo=DESPESA')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(lista.body.total).toBe(1);

      await request(app.getHttpServer())
        .delete(`/api/financeiro/lancamentos/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(204);

      await request(app.getHttpServer())
        .get(`/api/financeiro/lancamentos/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });

    it('valor negativo -> 400', async () => {
      const { token } = await cenarioBase('Academia Valor Invalido Lancamento E2E');

      await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'RECEITA', descricao: 'Venda avulsa', valor: -10, data: '2026-07-05' })
        .expect(400);
    });

    it('filtra por intervalo de data', async () => {
      const { token } = await cenarioBase('Academia Filtro Data Lancamento E2E');

      await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'RECEITA', descricao: 'Venda de produto', valor: 50, data: '2026-06-01' })
        .expect(201);
      await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'RECEITA', descricao: 'Venda de produto 2', valor: 60, data: '2026-07-01' })
        .expect(201);

      const julho = await request(app.getHttpServer())
        .get('/api/financeiro/lancamentos?dataInicio=2026-07-01&dataFim=2026-07-31')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(julho.body.total).toBe(1);
      expect(julho.body.items[0].valor).toBe(60);
    });

    it('filtra por mes/ano (competência) — mesmo eixo de Mensalidades, tem prioridade sobre dataInicio/dataFim', async () => {
      const { token } = await cenarioBase('Academia Filtro Competencia Lancamento E2E');

      await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'RECEITA', descricao: 'Venda de junho', valor: 50, data: '2026-06-15' })
        .expect(201);
      await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'RECEITA', descricao: 'Venda de julho', valor: 60, data: '2026-07-15' })
        .expect(201);

      const julho = await request(app.getHttpServer())
        .get('/api/financeiro/lancamentos?mes=7&ano=2026')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(julho.body.total).toBe(1);
      expect(julho.body.items[0].descricao).toBe('Venda de julho');
    });
  });

  describe('Lançamento gerado por Mensalidade paga é protegido', () => {
    it('não pode ser editado nem removido pelo CRUD genérico de Lançamento', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Lancamento Protegido E2E',
      });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
      const meUser = await prisma.user.findFirstOrThrow({ where: { academiaId: academia.id } });
      const aluno = await createAlunoFixture(prisma, academia.id);
      const plano = await createPlanoFixture(prisma, academia.id, { valor: 150 });
      await createMatriculaFixture(prisma, academia.id, aluno.id, plano.id, meUser.id);

      const geradas = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);
      const mensalidadeId = geradas.body.criadas[0].id;

      await request(app.getHttpServer())
        .patch(`/api/financeiro/mensalidades/${mensalidadeId}/pagar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ formaPagamento: 'PIX' })
        .expect(200);

      const lancamento = await prisma.lancamento.findFirstOrThrow({ where: { mensalidadeId } });
      expect(lancamento.origem).toBe('MENSALIDADE');

      const detalhe = await request(app.getHttpServer())
        .get(`/api/financeiro/lancamentos/${lancamento.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(detalhe.body.origem).toBe('MENSALIDADE');
      expect(detalhe.body.alunoNome).toBe(aluno.nome);
      expect(detalhe.body.mensalidadeDataVencimento).not.toBeNull();

      await request(app.getHttpServer())
        .patch(`/api/financeiro/lancamentos/${lancamento.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ valor: 999 })
        .expect(400);

      await request(app.getHttpServer())
        .delete(`/api/financeiro/lancamentos/${lancamento.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(400);
    });
  });

  describe('Resumo (Caixa)', () => {
    it('soma receitas/despesas do período (default: mês corrente) e calcula saldo/quantidades', async () => {
      const { token } = await cenarioBase('Academia Resumo Lancamento E2E');

      await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'RECEITA', descricao: 'Venda 1', valor: 100, data: '2026-07-10' })
        .expect(201);
      await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'RECEITA', descricao: 'Venda 2', valor: 50, data: '2026-07-20' })
        .expect(201);
      await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'DESPESA', descricao: 'Aluguel', valor: 80, data: '2026-07-05' })
        .expect(201);
      // fora do período — não deve entrar na soma de julho/2026
      await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'RECEITA', descricao: 'Venda de agosto', valor: 999, data: '2026-08-01' })
        .expect(201);

      const resumo = await request(app.getHttpServer())
        .get('/api/financeiro/lancamentos/resumo?mes=7&ano=2026')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(resumo.body.totalReceitas).toBe(150);
      expect(resumo.body.totalDespesas).toBe(80);
      expect(resumo.body.saldo).toBe(70);
      expect(resumo.body.quantidadeReceitas).toBe(2);
      expect(resumo.body.quantidadeDespesas).toBe(1);
    });

    it('período sem nenhum lançamento retorna tudo zerado', async () => {
      const { token } = await cenarioBase('Academia Resumo Vazio Lancamento E2E');

      const resumo = await request(app.getHttpServer())
        .get('/api/financeiro/lancamentos/resumo?mes=1&ano=2020')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(resumo.body).toEqual({
        totalReceitas: 0,
        totalDespesas: 0,
        saldo: 0,
        quantidadeReceitas: 0,
        quantidadeDespesas: 0,
      });
    });

    it('isola por tenant', async () => {
      const cenarioA = await cenarioBase('Academia Resumo Isolamento A E2E');
      const cenarioB = await cenarioBase('Academia Resumo Isolamento B E2E');

      await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${cenarioB.token}`)
        .send({ tipo: 'RECEITA', descricao: 'Venda B', valor: 500, data: '2026-07-10' })
        .expect(201);

      const resumoA = await request(app.getHttpServer())
        .get('/api/financeiro/lancamentos/resumo?mes=7&ano=2026')
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(200);

      expect(resumoA.body.totalReceitas).toBe(0);
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê nem edita lançamento da academia B', async () => {
      const cenarioA = await cenarioBase('Academia Isolamento Lancamento A E2E');
      const cenarioB = await cenarioBase('Academia Isolamento Lancamento B E2E');

      const criadoB = await request(app.getHttpServer())
        .post('/api/financeiro/lancamentos')
        .set('Authorization', `Bearer ${cenarioB.token}`)
        .send({ tipo: 'RECEITA', descricao: 'Venda B', valor: 100, data: '2026-07-05' })
        .expect(201);

      await request(app.getHttpServer())
        .get(`/api/financeiro/lancamentos/${criadoB.body.id}`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(404);

      await request(app.getHttpServer())
        .patch(`/api/financeiro/lancamentos/${criadoB.body.id}`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({ valor: 1 })
        .expect(404);
    });
  });
});
