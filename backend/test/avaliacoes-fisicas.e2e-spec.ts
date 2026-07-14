import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import { createAcademiaFixture, createAlunoFixture } from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

const SENHA = 'SenhaForte123';

describe('Avaliações Físicas (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string): Promise<string> {
    const email = `${role.toLowerCase()}-avaliacao-${Date.now()}-${Math.random()}@example.com`;
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
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Sem Token AF E2E' });
    const aluno = await createAlunoFixture(prisma, academia.id);

    await request(app.getHttpServer())
      .get(`/api/alunos/${aluno.id}/avaliacoes-fisicas`)
      .expect(401);
  });

  it('ALUNO não tem acesso (403)', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Aluno Sem Acesso AF E2E' });
    const aluno = await createAlunoFixture(prisma, academia.id);
    const token = await criarUsuarioELogar(Role.ALUNO, academia.id);

    await request(app.getHttpServer())
      .get(`/api/alunos/${aluno.id}/avaliacoes-fisicas`)
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  describe('CRUD', () => {
    it('ACADEMIA_ADMIN registra, lista (com IMC calculado) e remove uma avaliação', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia CRUD AF E2E' });
      const aluno = await createAlunoFixture(prisma, academia.id);
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      const criada = await request(app.getHttpServer())
        .post(`/api/alunos/${aluno.id}/avaliacoes-fisicas`)
        .set('Authorization', `Bearer ${token}`)
        .send({ data: '2026-07-01', peso: 70, altura: 175, observacoes: 'Primeira avaliação' })
        .expect(201);
      expect(criada.body.peso).toBe(70);
      expect(criada.body.altura).toBe(175);
      expect(criada.body.imc).toBeCloseTo(22.9, 1);
      expect(criada.body.observacoes).toBe('Primeira avaliação');

      const createAudit = await prisma.auditLog.findFirst({
        where: { action: 'AVALIACAO_FISICA_CREATED', academiaId: academia.id },
      });
      expect(createAudit).not.toBeNull();
      expect(createAudit?.ipAddress).toBeTruthy();

      const lista = await request(app.getHttpServer())
        .get(`/api/alunos/${aluno.id}/avaliacoes-fisicas`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(lista.body.total).toBe(1);
      expect(lista.body.items[0].id).toBe(criada.body.id);

      await request(app.getHttpServer())
        .delete(`/api/alunos/${aluno.id}/avaliacoes-fisicas/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(204);

      const listaAposRemover = await request(app.getHttpServer())
        .get(`/api/alunos/${aluno.id}/avaliacoes-fisicas`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(listaAposRemover.body.total).toBe(0);

      const linhaNoBanco = await prisma.avaliacaoFisica.findUnique({ where: { id: criada.body.id } });
      expect(linhaNoBanco).not.toBeNull();
      expect(linhaNoBanco?.deletedAt).not.toBeNull();

      const deleteAudit = await prisma.auditLog.findFirst({
        where: { action: 'AVALIACAO_FISICA_DELETED', academiaId: academia.id },
      });
      expect(deleteAudit).not.toBeNull();
    });

    it('PROFESSOR também pode registrar (sem trava de role, decisão de negócio)', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Professor Registra AF E2E' });
      const aluno = await createAlunoFixture(prisma, academia.id);
      const token = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

      await request(app.getHttpServer())
        .post(`/api/alunos/${aluno.id}/avaliacoes-fisicas`)
        .set('Authorization', `Bearer ${token}`)
        .send({ data: '2026-07-01', peso: 68, altura: 170 })
        .expect(201);
    });

    it('não existe rota de edição — apenas criar/listar/remover', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Sem Edicao AF E2E' });
      const aluno = await createAlunoFixture(prisma, academia.id);
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      const criada = await request(app.getHttpServer())
        .post(`/api/alunos/${aluno.id}/avaliacoes-fisicas`)
        .set('Authorization', `Bearer ${token}`)
        .send({ data: '2026-07-01', peso: 70, altura: 175 })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/alunos/${aluno.id}/avaliacoes-fisicas/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ peso: 999 })
        .expect(404);
    });

    it('registrar avaliação nunca altera o Aluno', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Invariante Aluno AF E2E' });
      const aluno = await createAlunoFixture(prisma, academia.id);
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      const antes = await prisma.aluno.findUniqueOrThrow({ where: { id: aluno.id } });

      await request(app.getHttpServer())
        .post(`/api/alunos/${aluno.id}/avaliacoes-fisicas`)
        .set('Authorization', `Bearer ${token}`)
        .send({ data: '2026-07-01', peso: 70, altura: 175 })
        .expect(201);

      const depois = await prisma.aluno.findUniqueOrThrow({ where: { id: aluno.id } });
      expect(depois.updatedAt.getTime()).toBe(antes.updatedAt.getTime());
    });

    it('peso/altura inválidos -> 400', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Peso Invalido AF E2E' });
      const aluno = await createAlunoFixture(prisma, academia.id);
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .post(`/api/alunos/${aluno.id}/avaliacoes-fisicas`)
        .set('Authorization', `Bearer ${token}`)
        .send({ data: '2026-07-01', peso: -5, altura: 175 })
        .expect(400);

      await request(app.getHttpServer())
        .post(`/api/alunos/${aluno.id}/avaliacoes-fisicas`)
        .set('Authorization', `Bearer ${token}`)
        .send({ data: 'não-é-uma-data', peso: 70, altura: 175 })
        .expect(400);
    });

    it('aluno inexistente -> 404', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Aluno Inexistente AF E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .post('/api/alunos/00000000-0000-0000-0000-000000000099/avaliacoes-fisicas')
        .set('Authorization', `Bearer ${token}`)
        .send({ data: '2026-07-01', peso: 70, altura: 175 })
        .expect(404);
    });

    it('avaliação de outro aluno -> 404', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Outro Aluno AF E2E' });
      const alunoA = await createAlunoFixture(prisma, academia.id);
      const alunoB = await createAlunoFixture(prisma, academia.id);
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      const avaliacaoDeA = await request(app.getHttpServer())
        .post(`/api/alunos/${alunoA.id}/avaliacoes-fisicas`)
        .set('Authorization', `Bearer ${token}`)
        .send({ data: '2026-07-01', peso: 70, altura: 175 })
        .expect(201);

      await request(app.getHttpServer())
        .delete(`/api/alunos/${alunoB.id}/avaliacoes-fisicas/${avaliacaoDeA.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê nem remove avaliação de aluno da academia B', async () => {
      const academiaA = await createAcademiaFixture(prisma, { nome: 'Academia Isolamento A AF E2E' });
      const academiaB = await createAcademiaFixture(prisma, { nome: 'Academia Isolamento B AF E2E' });
      const alunoB = await createAlunoFixture(prisma, academiaB.id);
      const tokenA = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaA.id);
      const tokenB = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaB.id);

      const avaliacaoB = await request(app.getHttpServer())
        .post(`/api/alunos/${alunoB.id}/avaliacoes-fisicas`)
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ data: '2026-07-01', peso: 70, altura: 175 })
        .expect(201);

      await request(app.getHttpServer())
        .get(`/api/alunos/${alunoB.id}/avaliacoes-fisicas`)
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(404);

      await request(app.getHttpServer())
        .delete(`/api/alunos/${alunoB.id}/avaliacoes-fisicas/${avaliacaoB.body.id}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(404);
    });
  });

  describe('Paginação e ordenação', () => {
    it('lista ordenada por data (mais recente primeiro)', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Ordenacao AF E2E' });
      const aluno = await createAlunoFixture(prisma, academia.id);
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .post(`/api/alunos/${aluno.id}/avaliacoes-fisicas`)
        .set('Authorization', `Bearer ${token}`)
        .send({ data: '2026-01-01', peso: 72, altura: 175 })
        .expect(201);
      await request(app.getHttpServer())
        .post(`/api/alunos/${aluno.id}/avaliacoes-fisicas`)
        .set('Authorization', `Bearer ${token}`)
        .send({ data: '2026-06-01', peso: 70, altura: 175 })
        .expect(201);

      const lista = await request(app.getHttpServer())
        .get(`/api/alunos/${aluno.id}/avaliacoes-fisicas`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      const datas = lista.body.items.map((item: { data: string }) => item.data);
      expect(new Date(datas[0]).getTime()).toBeGreaterThan(new Date(datas[1]).getTime());
    });
  });
});
