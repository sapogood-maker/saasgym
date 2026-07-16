import { INestApplication } from '@nestjs/common';
import { MotivoCancelamento, Role } from '@prisma/client';
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

describe('Relatórios (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string) {
    const email = `${role.toLowerCase()}-relatorios-${Date.now()}-${Math.random()}@example.com`;
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
    await request(app.getHttpServer()).get('/api/relatorios/receita').expect(401);
  });

  it('PROFESSOR não tem acesso (403)', async () => {
    const academia = await createAcademiaFixture(prisma, {
      nome: 'Academia Professor Sem Acesso Relatorios E2E',
    });
    const { token } = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    await request(app.getHttpServer())
      .get('/api/relatorios/receita')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  describe('Receita', () => {
    it('delega pro Painel Financeiro (mesma forma de evolução mensal)', async () => {
      const { academia, token, userId } = await cenarioBase('Academia Relatorios Receita E2E');
      const aluno = await createAlunoFixture(prisma, academia.id);
      const plano = await createPlanoFixture(prisma, academia.id, { valor: 150 });
      await createMatriculaFixture(prisma, academia.id, aluno.id, plano.id, userId, {
        valor: 150,
        dataInicio: new Date('2026-01-01'),
        dataFimPrevista: new Date('2026-12-31'),
        dataFim: new Date('2026-12-31'),
      });

      const receita = await request(app.getHttpServer())
        .get('/api/relatorios/receita?mes=7&ano=2026&meses=3')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(receita.body.meses).toHaveLength(3);
      expect(receita.body.meses[0]).toMatchObject({ mes: 7, ano: 2026, receitaPrevista: 150 });
    });
  });

  describe('Alunos', () => {
    it('conta novos alunos do mês (exclui renovação) e cancelamentos por motivo', async () => {
      const { academia, token, userId } = await cenarioBase('Academia Relatorios Alunos E2E');
      const plano = await createPlanoFixture(prisma, academia.id, { valor: 100 });

      // Datas fixas num mês bem no passado (2020-03), longe do "agora" real
      // usado pelo cenário de cancelamento logo abaixo — evita os dois se
      // sobreporem quando o teste roda no mesmo mês/ano corrente.
      const alunoNovo = await createAlunoFixture(prisma, academia.id);
      await createMatriculaFixture(prisma, academia.id, alunoNovo.id, plano.id, userId, {
        valor: 100,
        dataInicio: new Date('2020-03-05'),
        dataFimPrevista: new Date('2020-04-05'),
        dataFim: new Date('2020-04-05'),
      });

      // Renovação: matriculaAnteriorId preenchido -> não conta como "novo aluno"
      const alunoRenovado = await createAlunoFixture(prisma, academia.id);
      const anterior = await createMatriculaFixture(
        prisma,
        academia.id,
        alunoRenovado.id,
        plano.id,
        userId,
        {
          valor: 100,
          status: 'ENCERRADA',
          dataInicio: new Date('2020-02-01'),
          dataFimPrevista: new Date('2020-03-01'),
          dataFim: new Date('2020-03-01'),
        },
      );
      await createMatriculaFixture(prisma, academia.id, alunoRenovado.id, plano.id, userId, {
        valor: 100,
        dataInicio: new Date('2020-03-01'),
        dataFimPrevista: new Date('2020-04-01'),
        dataFim: new Date('2020-04-01'),
        matriculaAnteriorId: anterior.id,
      });

      // Cancelamento de verdade, via endpoint (updatedAt = agora)
      const alunoCancelado = await createAlunoFixture(prisma, academia.id);
      const matriculaCancelada = await createMatriculaFixture(
        prisma,
        academia.id,
        alunoCancelado.id,
        plano.id,
        userId,
        { valor: 100 },
      );
      await request(app.getHttpServer())
        .patch(`/api/matriculas/${matriculaCancelada.id}/cancelar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ motivoCancelamento: MotivoCancelamento.INADIMPLENCIA })
        .expect(200);

      const agora = new Date();
      const alunos = await request(app.getHttpServer())
        .get(
          `/api/relatorios/alunos?mes=${agora.getUTCMonth() + 1}&ano=${agora.getUTCFullYear()}&meses=1`,
        )
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      const mesAtual = alunos.body.meses[0];
      expect(mesAtual.cancelamentos).toBe(1);
      expect(mesAtual.cancelamentosPorMotivo).toEqual([
        { motivo: MotivoCancelamento.INADIMPLENCIA, quantidade: 1 },
      ]);

      const marco2020 = await request(app.getHttpServer())
        .get('/api/relatorios/alunos?mes=3&ano=2020&meses=1')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(marco2020.body.meses[0].novosAlunos).toBe(1);
      expect(marco2020.body.meses[0].cancelamentos).toBe(0);
      expect(marco2020.body.meses[0].saldoLiquido).toBe(1);
    });

    it('isola por tenant', async () => {
      const cenarioA = await cenarioBase('Academia Relatorios Alunos Isolamento A E2E');
      const cenarioB = await cenarioBase('Academia Relatorios Alunos Isolamento B E2E');
      const alunoB = await createAlunoFixture(prisma, cenarioB.academia.id);
      const planoB = await createPlanoFixture(prisma, cenarioB.academia.id, { valor: 500 });
      await createMatriculaFixture(
        prisma,
        cenarioB.academia.id,
        alunoB.id,
        planoB.id,
        cenarioB.userId,
        {
          valor: 500,
          dataInicio: new Date('2026-07-05'),
          dataFimPrevista: new Date('2026-08-05'),
          dataFim: new Date('2026-08-05'),
        },
      );

      const alunosA = await request(app.getHttpServer())
        .get('/api/relatorios/alunos?mes=7&ano=2026&meses=1')
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(200);

      expect(alunosA.body.meses[0].novosAlunos).toBe(0);
    });
  });

  describe('Resumo', () => {
    it('conta alunos ativos hoje e aproxima a retenção', async () => {
      const { academia, token, userId } = await cenarioBase('Academia Relatorios Resumo E2E');
      const aluno = await createAlunoFixture(prisma, academia.id, { status: 'ATIVO' });
      const plano = await createPlanoFixture(prisma, academia.id, { valor: 100 });
      await createMatriculaFixture(prisma, academia.id, aluno.id, plano.id, userId, { valor: 100 });

      const resumo = await request(app.getHttpServer())
        .get('/api/relatorios/resumo')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(resumo.body.meses).toBe(6);
      expect(resumo.body.alunosAtivosHoje).toBeGreaterThanOrEqual(1);
      expect(resumo.body.cancelamentosPeriodo).toBe(0);
      expect(resumo.body.taxaRetencaoAproximada).toBe(1);
    });

    it('isola por tenant', async () => {
      const cenarioA = await cenarioBase('Academia Relatorios Resumo Isolamento A E2E');
      const cenarioB = await cenarioBase('Academia Relatorios Resumo Isolamento B E2E');
      await createAlunoFixture(prisma, cenarioB.academia.id, { status: 'ATIVO' });

      const resumoA = await request(app.getHttpServer())
        .get('/api/relatorios/resumo')
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(200);

      expect(resumoA.body.alunosAtivosHoje).toBe(0);
    });
  });
});
