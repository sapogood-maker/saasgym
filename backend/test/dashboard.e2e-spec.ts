import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import {
  createAcademiaFixture,
  createAlunoFixture,
  createMatriculaFixture,
  createModalidadeFixture,
  createPlanoFixture,
  createProfessorFixture,
} from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

/// Meia-noite UTC do dia — mesma construção de `Aula.data`/`Mensalidade.dataVencimento`
/// em produção (`dataVencimentoNoMes`), não um timestamp com hora corrente.
function diasAPartirDeHoje(dias: number): Date {
  const agora = new Date();
  const hoje = Date.UTC(agora.getUTCFullYear(), agora.getUTCMonth(), agora.getUTCDate());
  return new Date(hoje + dias * 24 * 60 * 60 * 1000);
}

const SENHA = 'SenhaForte123';

describe('Dashboard da academia (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string): Promise<string> {
    const email = `${role.toLowerCase()}-dash-${Date.now()}-${Math.random()}@example.com`;
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
    return res.body.accessToken;
  }

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('sem token -> 401', async () => {
    await request(app.getHttpServer()).get('/api/dashboard').expect(401);
  });

  it('PROFESSOR -> 403 (só ACADEMIA_ADMIN/RECEPCIONISTA)', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Dashboard 403 E2E' });
    const token = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    await request(app.getHttpServer())
      .get('/api/dashboard')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  it('agregados refletem dados reais da própria academia', async () => {
    const academia = await createAcademiaFixture(prisma, {
      nome: 'Academia Dashboard Agregados E2E',
    });
    const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

    await request(app.getHttpServer())
      .post('/api/alunos')
      .set('Authorization', `Bearer ${token}`)
      .send({
        nome: 'Aluno Ativo Dashboard',
        cpf: '111.444.777-35',
        dataNascimento: '1990-03-15',
        sexo: 'MASCULINO',
        telefone: '11999999999',
      })
      .expect(201);
    const inativo = await request(app.getHttpServer())
      .post('/api/alunos')
      .set('Authorization', `Bearer ${token}`)
      .send({
        nome: 'Aluno Inativo Dashboard',
        cpf: '529.982.247-25',
        dataNascimento: '1990-03-15',
        sexo: 'FEMININO',
        telefone: '11988887777',
      })
      .expect(201);
    await request(app.getHttpServer())
      .patch(`/api/alunos/${inativo.body.id}/status`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'INATIVO' })
      .expect(200);

    await request(app.getHttpServer())
      .post('/api/professores')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Professor Dashboard', cpf: '390.533.447-05', telefone: '11977776666' })
      .expect(201);

    const res = await request(app.getHttpServer())
      .get('/api/dashboard')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(res.body.totalAlunos).toBe(2);
    expect(res.body.alunosAtivos).toBe(1);
    expect(res.body.totalProfessores).toBe(1);
    expect(res.body.novosAlunosMes).toBe(2);
    // ACADEMIA_ADMIN logado conta como usuário do sistema.
    expect(res.body.usuariosDoSistema).toBeGreaterThanOrEqual(1);
  });

  it('aniversariantes: só alunos com dataNascimento no mês atual, isolado por academia', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Aniversariantes E2E' });
    const outraAcademia = await createAcademiaFixture(prisma, {
      nome: 'Academia Aniversariantes Outra E2E',
    });
    const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    const tokenOutra = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, outraAcademia.id);

    const mesAtual = String(new Date().getMonth() + 1).padStart(2, '0');
    const mesQueNaoEAtual = mesAtual === '01' ? '02' : '01';

    const aniversariante = await request(app.getHttpServer())
      .post('/api/alunos')
      .set('Authorization', `Bearer ${token}`)
      .send({
        nome: 'Aniversariante Do Mês',
        cpf: '111.444.777-35',
        dataNascimento: `1990-${mesAtual}-10`,
        sexo: 'OUTRO',
        telefone: '11999999999',
      })
      .expect(201);

    await request(app.getHttpServer())
      .post('/api/alunos')
      .set('Authorization', `Bearer ${token}`)
      .send({
        nome: 'Não Aniversariante',
        cpf: '529.982.247-25',
        dataNascimento: `1990-${mesQueNaoEAtual}-10`,
        sexo: 'OUTRO',
        telefone: '11988887777',
      })
      .expect(201);

    // aniversariante em OUTRA academia, mesmo mês — não pode vazar para
    // a consulta da primeira academia (prova o filtro manual de
    // academiaId no $queryRaw).
    await request(app.getHttpServer())
      .post('/api/alunos')
      .set('Authorization', `Bearer ${tokenOutra}`)
      .send({
        nome: 'Aniversariante De Outra Academia',
        cpf: '111.444.777-35',
        dataNascimento: `1985-${mesAtual}-20`,
        sexo: 'OUTRO',
        telefone: '11977776666',
      })
      .expect(201);

    const res = await request(app.getHttpServer())
      .get('/api/dashboard')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(res.body.aniversariantes).toHaveLength(1);
    expect(res.body.aniversariantes[0].id).toBe(aniversariante.body.id);
    expect(res.body.aniversariantes[0].nome).toBe('Aniversariante Do Mês');
  });

  describe('aulasSemana (docs/22, Centro de Operações)', () => {
    it('traz só aulas dentro da janela hoje..hoje+7 (inclusive), fora da janela fica de fora', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Agenda Semana E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
      const modalidade = await createModalidadeFixture(prisma, academia.id);
      const professor = await createProfessorFixture(prisma, academia.id);
      const usuario = await prisma.user.findFirstOrThrow({ where: { academiaId: academia.id } });

      const turma = await request(app.getHttpServer())
        .post('/api/agenda/turmas')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Turma Dashboard Semana', modalidadeId: modalidade.id, professorId: professor.id })
        .expect(201);

      const criarAula = (data: Date) =>
        prisma.aula.create({
          data: {
            academiaId: academia.id,
            turmaId: turma.body.id,
            recorrenciaId: null,
            data,
            horaInicio: '07:00',
            duracaoMinutos: 60,
            professorId: professor.id,
            status: 'AGENDADA',
            createdByUserId: usuario.id,
          },
        });

      const dentroDaJanelaHoje = await criarAula(diasAPartirDeHoje(0));
      const dentroDaJanelaFuturo = await criarAula(diasAPartirDeHoje(3));
      const dentroDaJanelaLimite = await criarAula(diasAPartirDeHoje(7)); // limite inclusive
      await criarAula(diasAPartirDeHoje(-1)); // ontem — fora da janela
      await criarAula(diasAPartirDeHoje(8)); // um dia além do limite — fora da janela

      const res = await request(app.getHttpServer())
        .get('/api/dashboard')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      const idsRetornados = res.body.aulasSemana.map((a: { id: string }) => a.id);
      expect(idsRetornados).toEqual(
        expect.arrayContaining([dentroDaJanelaHoje.id, dentroDaJanelaFuturo.id, dentroDaJanelaLimite.id]),
      );
      expect(res.body.aulasSemana).toHaveLength(3);
    });
  });

  describe('financeiro (docs/22, Centro de Operações)', () => {
    it('resumo do mês corrente + mensalidadesAlerta combina vencidas e a vencer em 7 dias, ordenadas, capadas em 10', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Financeiro Dashboard E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
      const usuario = await prisma.user.findFirstOrThrow({ where: { academiaId: academia.id } });
      const aluno = await createAlunoFixture(prisma, academia.id);
      const plano = await createPlanoFixture(prisma, academia.id, { valor: 100 });
      const agora = new Date();
      const matricula = await createMatriculaFixture(prisma, academia.id, aluno.id, plano.id, usuario.id, {
        valor: 100,
        dataInicio: new Date(Date.UTC(agora.getUTCFullYear(), 0, 1)),
        dataFimPrevista: new Date(Date.UTC(agora.getUTCFullYear() + 1, 0, 1)),
        dataFim: new Date(Date.UTC(agora.getUTCFullYear() + 1, 0, 1)),
      });

      const criarMensalidade = (dataVencimento: Date, status: 'PENDENTE' | 'PAGA' = 'PENDENTE') =>
        prisma.mensalidade.create({
          data: {
            academiaId: academia.id,
            matriculaId: matricula.id,
            alunoId: aluno.id,
            valor: 100,
            dataVencimento,
            status,
            createdByUserId: usuario.id,
          },
        });

      const vencidaAntiga = await criarMensalidade(new Date('2020-01-10'));
      const aVencerEm3Dias = await criarMensalidade(diasAPartirDeHoje(3));
      await criarMensalidade(diasAPartirDeHoje(8)); // fora da janela (limite é hoje+7 inclusive)
      await criarMensalidade(new Date('2019-01-10'), 'PAGA'); // paga não entra no alerta

      const res = await request(app.getHttpServer())
        .get('/api/dashboard')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.financeiro.receitaPrevista).toBe(100);
      expect(res.body.financeiro.inadimplenciaValor).toBe(100);
      expect(res.body.financeiro.inadimplenciaQuantidade).toBe(1);

      expect(res.body.financeiro.mensalidadesAlerta).toHaveLength(2);
      expect(res.body.financeiro.mensalidadesAlerta[0]).toMatchObject({
        id: vencidaAntiga.id,
        vencida: true,
      });
      expect(res.body.financeiro.mensalidadesAlerta[1]).toMatchObject({
        id: aVencerEm3Dias.id,
        vencida: false,
      });
    });
  });
});
