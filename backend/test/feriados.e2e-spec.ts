import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import { createAcademiaFixture } from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

const SENHA = 'SenhaForte123';

describe('Feriados (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string): Promise<string> {
    const email = `${role.toLowerCase()}-feriados-${Date.now()}-${Math.random()}@example.com`;
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
    await request(app.getHttpServer()).get('/api/agenda/feriados').expect(401);
  });

  it('PROFESSOR não tem acesso (403)', async () => {
    const academia = await createAcademiaFixture(prisma, {
      nome: 'Academia Professor Sem Acesso Feriado E2E',
    });
    const token = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    await request(app.getHttpServer())
      .get('/api/agenda/feriados')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  describe('CRUD', () => {
    it('ACADEMIA_ADMIN cria, lista, detalha, edita e remove um feriado', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia CRUD Feriado E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      const criado = await request(app.getHttpServer())
        .post('/api/agenda/feriados')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Natal', data: '2026-12-25' })
        .expect(201);
      expect(criado.body.nome).toBe('Natal');

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'FERIADO_CREATED', academiaId: academia.id },
      });
      expect(auditEntry).not.toBeNull();
      expect(auditEntry?.ipAddress).toBeTruthy();

      const detalhe = await request(app.getHttpServer())
        .get(`/api/agenda/feriados/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(detalhe.body.nome).toBe('Natal');

      const editado = await request(app.getHttpServer())
        .patch(`/api/agenda/feriados/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Natal (ajustado)' })
        .expect(200);
      expect(editado.body.nome).toBe('Natal (ajustado)');

      const updateAudit = await prisma.auditLog.findFirst({
        where: { action: 'FERIADO_UPDATED', academiaId: academia.id },
      });
      expect(updateAudit).not.toBeNull();

      await request(app.getHttpServer())
        .delete(`/api/agenda/feriados/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(204);

      await request(app.getHttpServer())
        .get(`/api/agenda/feriados/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(404);

      const linhaNoBanco = await prisma.feriado.findUnique({ where: { id: criado.body.id } });
      expect(linhaNoBanco).not.toBeNull();
      expect(linhaNoBanco?.deletedAt).not.toBeNull();

      const deleteAudit = await prisma.auditLog.findFirst({
        where: { action: 'FERIADO_DELETED', academiaId: academia.id },
      });
      expect(deleteAudit).not.toBeNull();
    });

    it('data inválida -> 400', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Data Invalida Feriado E2E',
      });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .post('/api/agenda/feriados')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Feriado Ruim', data: 'não-é-uma-data' })
        .expect(400);
    });

    it('data duplicada na mesma academia -> 409', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Data Duplicada Feriado E2E',
      });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
      const payload = { nome: 'Ano Novo', data: '2027-01-01' };

      await request(app.getHttpServer())
        .post('/api/agenda/feriados')
        .set('Authorization', `Bearer ${token}`)
        .send(payload)
        .expect(201);

      await request(app.getHttpServer())
        .post('/api/agenda/feriados')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Outro nome, mesma data', data: '2027-01-01' })
        .expect(409);
    });

    it('mesma data em academias diferentes é permitida', async () => {
      const academiaA = await createAcademiaFixture(prisma, {
        nome: 'Academia Data Repetida A Feriado E2E',
      });
      const academiaB = await createAcademiaFixture(prisma, {
        nome: 'Academia Data Repetida B Feriado E2E',
      });
      const tokenA = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaA.id);
      const tokenB = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaB.id);
      const payload = { nome: 'Tiradentes', data: '2027-04-21' };

      await request(app.getHttpServer())
        .post('/api/agenda/feriados')
        .set('Authorization', `Bearer ${tokenA}`)
        .send(payload)
        .expect(201);

      await request(app.getHttpServer())
        .post('/api/agenda/feriados')
        .set('Authorization', `Bearer ${tokenB}`)
        .send(payload)
        .expect(201);
    });

    it('id inexistente -> 404', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia 404 Feriado E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .get('/api/agenda/feriados/00000000-0000-0000-0000-000000000099')
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê, não edita e não deleta feriado da academia B', async () => {
      const academiaA = await createAcademiaFixture(prisma, {
        nome: 'Academia Isolamento A Feriado E2E',
      });
      const academiaB = await createAcademiaFixture(prisma, {
        nome: 'Academia Isolamento B Feriado E2E',
      });
      const tokenA = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaA.id);
      const tokenB = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaB.id);

      const feriadoB = await request(app.getHttpServer())
        .post('/api/agenda/feriados')
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ nome: 'Feriado da B', data: '2027-09-07' })
        .expect(201);

      await request(app.getHttpServer())
        .get(`/api/agenda/feriados/${feriadoB.body.id}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(404);

      await request(app.getHttpServer())
        .patch(`/api/agenda/feriados/${feriadoB.body.id}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ nome: 'Hackeado' })
        .expect(404);

      await request(app.getHttpServer())
        .delete(`/api/agenda/feriados/${feriadoB.body.id}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(404);

      const listaA = await request(app.getHttpServer())
        .get('/api/agenda/feriados')
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(200);
      expect(listaA.body.items.some((f: { id: string }) => f.id === feriadoB.body.id)).toBe(false);
    });
  });

  describe('Paginação e ordenação', () => {
    it('lista ordenada por data (ascendente)', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Ordenacao Feriado E2E',
      });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .post('/api/agenda/feriados')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Feriado de Dezembro', data: '2028-12-25' })
        .expect(201);
      await request(app.getHttpServer())
        .post('/api/agenda/feriados')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Feriado de Janeiro', data: '2028-01-01' })
        .expect(201);

      const lista = await request(app.getHttpServer())
        .get('/api/agenda/feriados')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      const datas = lista.body.items.map((f: { data: string }) => f.data);
      const datasOrdenadas = [...datas].sort();
      expect(datas).toEqual(datasOrdenadas);
    });
  });
});
