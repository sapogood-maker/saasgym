import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import { createAcademiaFixture } from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

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
});
