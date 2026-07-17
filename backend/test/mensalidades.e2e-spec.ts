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

describe('Mensalidades (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string) {
    const email = `${role.toLowerCase()}-mensalidades-${Date.now()}-${Math.random()}@example.com`;
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

  /// Academia + aluno + plano + 1 matrícula ATIVA cuja vigência cobre
  /// julho/2026 (mesmo mês usado em todo o describe abaixo).
  async function cenarioBase(nomeAcademia: string) {
    const academia = await createAcademiaFixture(prisma, { nome: nomeAcademia });
    const { token, userId } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    const aluno = await createAlunoFixture(prisma, academia.id);
    const plano = await createPlanoFixture(prisma, academia.id, { valor: 150 });
    const matricula = await createMatriculaFixture(prisma, academia.id, aluno.id, plano.id, userId);
    return { academia, token, userId, aluno, plano, matricula };
  }

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('sem token -> 401', async () => {
    await request(app.getHttpServer()).get('/api/financeiro/mensalidades').expect(401);
  });

  it('PROFESSOR não tem acesso (403) — dado financeiro, diferente de Planos/Matrículas', async () => {
    const academia = await createAcademiaFixture(prisma, {
      nome: 'Academia Professor Sem Acesso Mensalidade',
    });
    const { token } = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    await request(app.getHttpServer())
      .get('/api/financeiro/mensalidades')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  describe('Geração', () => {
    it('gera 1 mensalidade pra matrícula ATIVA cuja vigência cobre o mês', async () => {
      const { token, aluno, matricula } = await cenarioBase('Academia Gerar Mensalidade E2E');

      const res = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);

      expect(res.body.criadas).toHaveLength(1);
      expect(res.body.criadas[0].matriculaId).toBe(matricula.id);
      expect(res.body.criadas[0].alunoNome).toBe(aluno.nome);
      expect(res.body.criadas[0].valor).toBe(150);
      expect(res.body.criadas[0].valorFinal).toBe(150);
      expect(res.body.criadas[0].status).toBe('PENDENTE');
      expect(new Date(res.body.criadas[0].dataVencimento).toISOString().slice(0, 10)).toBe(
        '2026-07-10',
      );
      expect(res.body.totalPuladas).toBe(0);
    });

    it('idempotente — gerar de novo pro mesmo mês não duplica', async () => {
      const { token } = await cenarioBase('Academia Gerar Idempotente E2E');

      await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);

      const segunda = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);

      expect(segunda.body.criadas).toHaveLength(0);
      expect(segunda.body.totalPuladas).toBe(1);
    });

    it('não gera pra matrícula cuja vigência já terminou antes do mês alvo', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Vigencia Vencida E2E',
      });
      const { token, userId } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
      const aluno = await createAlunoFixture(prisma, academia.id);
      const plano = await createPlanoFixture(prisma, academia.id);
      // Vigência termina em fevereiro/2026 — gerar pra julho/2026 não deve pegar essa matrícula.
      await createMatriculaFixture(prisma, academia.id, aluno.id, plano.id, userId, {
        dataInicio: new Date('2026-01-10'),
        dataFimPrevista: new Date('2026-02-10'),
        dataFim: new Date('2026-02-10'),
      });

      const res = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);

      expect(res.body.criadas).toHaveLength(0);
    });

    it('não gera pra matrícula TRANCADA/CANCELADA/ENCERRADA', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Nao Ativa E2E' });
      const { token, userId } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
      const aluno = await createAlunoFixture(prisma, academia.id);
      const plano = await createPlanoFixture(prisma, academia.id);
      await createMatriculaFixture(prisma, academia.id, aluno.id, plano.id, userId, {
        status: 'TRANCADA',
      });

      const res = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);

      expect(res.body.criadas).toHaveLength(0);
    });
  });

  describe('Listagem e detalhe', () => {
    it('lista com filtro por matrícula e por mês/ano', async () => {
      const { token, matricula } = await cenarioBase('Academia Listar Mensalidade E2E');
      await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);

      const porMatricula = await request(app.getHttpServer())
        .get(`/api/financeiro/mensalidades?matriculaId=${matricula.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(porMatricula.body.total).toBe(1);

      const porMes = await request(app.getHttpServer())
        .get('/api/financeiro/mensalidades?mes=7&ano=2026')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(porMes.body.total).toBe(1);

      const semMesCorrespondente = await request(app.getHttpServer())
        .get('/api/financeiro/mensalidades?mes=8&ano=2026')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(semMesCorrespondente.body.total).toBe(0);
    });

    it('id inexistente -> 404', async () => {
      const { token } = await cenarioBase('Academia 404 Mensalidade E2E');
      await request(app.getHttpServer())
        .get('/api/financeiro/mensalidades/00000000-0000-0000-0000-000000000099')
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });

    it('search filtra por nome do aluno (contains, case-insensitive) — complemento à navegação por competência', async () => {
      const { token, aluno } = await cenarioBase('Academia Search Mensalidade E2E');
      await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);

      const trecho = aluno.nome.slice(0, 5).toUpperCase();
      const encontrada = await request(app.getHttpServer())
        .get(`/api/financeiro/mensalidades?search=${encodeURIComponent(trecho)}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(encontrada.body.total).toBe(1);
      expect(encontrada.body.items[0].alunoNome).toBe(aluno.nome);

      const semResultado = await request(app.getHttpServer())
        .get('/api/financeiro/mensalidades?search=NomeQueNaoExisteNestaAcademia')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(semResultado.body.total).toBe(0);
    });
  });

  describe('Editar', () => {
    it('aplica desconto/multa enquanto PENDENTE', async () => {
      const { token } = await cenarioBase('Academia Editar Mensalidade E2E');
      const geradas = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);
      const id = geradas.body.criadas[0].id;

      const editada = await request(app.getHttpServer())
        .patch(`/api/financeiro/mensalidades/${id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ desconto: 20, multa: 5 })
        .expect(200);

      expect(editada.body.desconto).toBe(20);
      expect(editada.body.multa).toBe(5);
      expect(editada.body.valorFinal).toBe(135);
    });

    it('bloqueia desconto que deixaria o valor final negativo (validação cruzada)', async () => {
      const { token } = await cenarioBase('Academia Desconto Invalido E2E');
      const geradas = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);
      const id = geradas.body.criadas[0].id;

      // Matricula de cenarioBase tem valor 150 — desconto de 200 sem multa
      // deixaria o valorFinal em -50.
      const resposta = await request(app.getHttpServer())
        .patch(`/api/financeiro/mensalidades/${id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ desconto: 200 })
        .expect(400);
      expect(resposta.body.message).toContain('valor final da mensalidade negativo');

      // Nada foi alterado — desconto continua 0.
      const inalterada = await request(app.getHttpServer())
        .get(`/api/financeiro/mensalidades/${id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(inalterada.body.desconto).toBe(0);
    });

    it('permite desconto igual ao valor (valorFinal zero é um estado válido — cortesia)', async () => {
      const { token } = await cenarioBase('Academia Desconto Total E2E');
      const geradas = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);
      const id = geradas.body.criadas[0].id;

      const editada = await request(app.getHttpServer())
        .patch(`/api/financeiro/mensalidades/${id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ desconto: 150 })
        .expect(200);
      expect(editada.body.valorFinal).toBe(0);
    });
  });

  describe('Marcar como paga', () => {
    it('marca como paga, gera o Lancamento correspondente e audita', async () => {
      const { academia, token } = await cenarioBase('Academia Pagar Mensalidade E2E');
      const geradas = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);
      const id = geradas.body.criadas[0].id;

      const paga = await request(app.getHttpServer())
        .patch(`/api/financeiro/mensalidades/${id}/pagar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ formaPagamento: 'PIX' })
        .expect(200);

      expect(paga.body.status).toBe('PAGA');
      expect(paga.body.dataPagamento).toBeTruthy();
      expect(paga.body.formaPagamento).toBe('PIX');

      const lancamento = await prisma.lancamento.findFirst({ where: { mensalidadeId: id } });
      expect(lancamento).not.toBeNull();
      expect(lancamento?.tipo).toBe('RECEITA');
      expect(Number(lancamento?.valor)).toBe(150);
      expect(lancamento?.formaPagamento).toBe('PIX');

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'MENSALIDADE_PAGA', academiaId: academia.id },
      });
      expect(auditEntry).not.toBeNull();
    });

    it('não permite pagar uma mensalidade já paga', async () => {
      const { token } = await cenarioBase('Academia Pagar Duas Vezes E2E');
      const geradas = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);
      const id = geradas.body.criadas[0].id;

      await request(app.getHttpServer())
        .patch(`/api/financeiro/mensalidades/${id}/pagar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ formaPagamento: 'DINHEIRO' })
        .expect(200);

      await request(app.getHttpServer())
        .patch(`/api/financeiro/mensalidades/${id}/pagar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ formaPagamento: 'DINHEIRO' })
        .expect(400);
    });
  });

  describe('Cancelar', () => {
    it('cancela uma mensalidade PENDENTE', async () => {
      const { token } = await cenarioBase('Academia Cancelar Mensalidade E2E');
      const geradas = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);
      const id = geradas.body.criadas[0].id;

      const cancelada = await request(app.getHttpServer())
        .patch(`/api/financeiro/mensalidades/${id}/cancelar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ motivo: 'Gerada por engano' })
        .expect(200);

      expect(cancelada.body.status).toBe('CANCELADA');
      expect(cancelada.body.motivoCancelamento).toBe('Gerada por engano');
    });

    it('não permite cancelar uma mensalidade já paga', async () => {
      const { token } = await cenarioBase('Academia Cancelar Paga E2E');
      const geradas = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);
      const id = geradas.body.criadas[0].id;

      await request(app.getHttpServer())
        .patch(`/api/financeiro/mensalidades/${id}/pagar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ formaPagamento: 'PIX' })
        .expect(200);

      await request(app.getHttpServer())
        .patch(`/api/financeiro/mensalidades/${id}/cancelar`)
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(400);
    });
  });

  describe('Remover', () => {
    it('remove (soft delete) uma mensalidade PENDENTE', async () => {
      const { token } = await cenarioBase('Academia Remover Mensalidade E2E');
      const geradas = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);
      const id = geradas.body.criadas[0].id;

      await request(app.getHttpServer())
        .delete(`/api/financeiro/mensalidades/${id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(204);

      await request(app.getHttpServer())
        .get(`/api/financeiro/mensalidades/${id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });

    it('bloqueia remoção de uma mensalidade PAGA (o lançamento ficaria órfão)', async () => {
      const { token } = await cenarioBase('Academia Remover Paga E2E');
      const geradas = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);
      const id = geradas.body.criadas[0].id;

      await request(app.getHttpServer())
        .patch(`/api/financeiro/mensalidades/${id}/pagar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ formaPagamento: 'PIX' })
        .expect(200);

      await request(app.getHttpServer())
        .delete(`/api/financeiro/mensalidades/${id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(400);
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê nem paga mensalidade da academia B', async () => {
      const cenarioA = await cenarioBase('Academia Isolamento Mensalidade A E2E');
      const cenarioB = await cenarioBase('Academia Isolamento Mensalidade B E2E');

      const geradasB = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${cenarioB.token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);
      const idB = geradasB.body.criadas[0].id;

      await request(app.getHttpServer())
        .get(`/api/financeiro/mensalidades/${idB}`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(404);

      await request(app.getHttpServer())
        .patch(`/api/financeiro/mensalidades/${idB}/pagar`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({ formaPagamento: 'PIX' })
        .expect(404);
    });
  });

  /// Sprint de Integridade Financeira (docs/29-auditoria-financeiro-estrutural.md)
  describe('Duplicidade', () => {
    it('o banco rejeita duas mensalidades pro mesmo (matriculaId, dataVencimento)', async () => {
      const { academia, matricula, userId } = await cenarioBase(
        'Academia Duplicidade Mensalidade E2E',
      );

      await prisma.mensalidade.create({
        data: {
          academiaId: academia.id,
          matriculaId: matricula.id,
          alunoId: matricula.alunoId,
          valor: 150,
          dataVencimento: new Date('2026-07-10'),
          createdByUserId: userId,
        },
      });

      await expect(
        prisma.mensalidade.create({
          data: {
            academiaId: academia.id,
            matriculaId: matricula.id,
            alunoId: matricula.alunoId,
            valor: 150,
            dataVencimento: new Date('2026-07-10'),
            createdByUserId: userId,
          },
        }),
      ).rejects.toThrow();
    });

    it('gerar() manual não duplica mensalidade já coberta pela geração automática na criação da matrícula', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Sem Duplicar Geracao Automatica E2E',
      });
      const { token } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
      const aluno = await createAlunoFixture(prisma, academia.id);
      const plano = await request(app.getHttpServer())
        .post('/api/planos')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Plano Sem Duplicar E2E', periodicidade: 'MENSAL', valor: 150 })
        .expect(201);

      const matricula = await request(app.getHttpServer())
        .post('/api/matriculas')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id, planoId: plano.body.id, dataInicio: '2026-07-10' })
        .expect(201);

      // A mensalidade de julho/2026 já nasceu automaticamente com a
      // matrícula — chamar "gerar" manualmente pro mesmo mês não duplica.
      const gerada = await request(app.getHttpServer())
        .post('/api/financeiro/mensalidades/gerar')
        .set('Authorization', `Bearer ${token}`)
        .send({ mes: 7, ano: 2026 })
        .expect(201);
      expect(gerada.body.criadas).toHaveLength(0);
      expect(gerada.body.totalPuladas).toBe(1);

      const mensalidades = await request(app.getHttpServer())
        .get(`/api/financeiro/mensalidades?matriculaId=${matricula.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(mensalidades.body.total).toBe(1);
    });
  });
});
