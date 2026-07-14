import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import { createAcademiaFixture } from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

const SENHA = 'SenhaForte123';

describe('Modalidades (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string): Promise<string> {
    const email = `${role.toLowerCase()}-modalidades-${Date.now()}-${Math.random()}@example.com`;
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
    await request(app.getHttpServer()).get('/api/agenda/modalidades').expect(401);
  });

  it('PROFESSOR não tem acesso (403) — diferente de Planos, Agenda não abre leitura pra Professor', async () => {
    const academia = await createAcademiaFixture(prisma, {
      nome: 'Academia Professor Sem Acesso Modalidade E2E',
    });
    const token = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    await request(app.getHttpServer())
      .get('/api/agenda/modalidades')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  describe('CRUD', () => {
    it('ACADEMIA_ADMIN cria, lista, detalha, edita e ativa/inativa uma modalidade', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia CRUD Modalidade E2E',
      });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      const criada = await request(app.getHttpServer())
        .post('/api/agenda/modalidades')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Funcional', cor: '#3B82F6' })
        .expect(201);
      expect(criada.body.status).toBe('ATIVO');
      expect(criada.body.cor).toBe('#3B82F6');

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'MODALIDADE_CREATED', academiaId: academia.id },
      });
      expect(auditEntry).not.toBeNull();
      expect(auditEntry?.ipAddress).toBeTruthy();

      const detalhe = await request(app.getHttpServer())
        .get(`/api/agenda/modalidades/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(detalhe.body.nome).toBe('Funcional');

      const editada = await request(app.getHttpServer())
        .patch(`/api/agenda/modalidades/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ cor: '#22C55E' })
        .expect(200);
      expect(editada.body.cor).toBe('#22C55E');

      const inativada = await request(app.getHttpServer())
        .patch(`/api/agenda/modalidades/${criada.body.id}/status`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'INATIVO', motivo: 'Descontinuada' })
        .expect(200);
      expect(inativada.body.status).toBe('INATIVO');

      const statusAudit = await prisma.auditLog.findFirst({
        where: { action: 'MODALIDADE_STATUS_CHANGED', academiaId: academia.id },
      });
      expect(statusAudit?.metadata).toMatchObject({
        statusNovo: 'INATIVO',
        motivo: 'Descontinuada',
      });
    });

    it('cor em formato inválido -> 400', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Cor Invalida Modalidade E2E',
      });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .post('/api/agenda/modalidades')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Cor Ruim', cor: 'azul' })
        .expect(400);
    });

    it('nome duplicado na mesma academia -> 409', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Nome Duplicado Modalidade E2E',
      });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
      const payload = { nome: 'Musculação' };

      await request(app.getHttpServer())
        .post('/api/agenda/modalidades')
        .set('Authorization', `Bearer ${token}`)
        .send(payload)
        .expect(201);

      await request(app.getHttpServer())
        .post('/api/agenda/modalidades')
        .set('Authorization', `Bearer ${token}`)
        .send(payload)
        .expect(409);
    });

    it('mesmo nome em academias diferentes é permitido', async () => {
      const academiaA = await createAcademiaFixture(prisma, {
        nome: 'Academia Nome Repetido A Modalidade E2E',
      });
      const academiaB = await createAcademiaFixture(prisma, {
        nome: 'Academia Nome Repetido B Modalidade E2E',
      });
      const tokenA = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaA.id);
      const tokenB = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaB.id);
      const payload = { nome: 'Spinning' };

      await request(app.getHttpServer())
        .post('/api/agenda/modalidades')
        .set('Authorization', `Bearer ${tokenA}`)
        .send(payload)
        .expect(201);

      await request(app.getHttpServer())
        .post('/api/agenda/modalidades')
        .set('Authorization', `Bearer ${tokenB}`)
        .send(payload)
        .expect(201);
    });

    it('id inexistente -> 404', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia 404 Modalidade E2E',
      });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .get('/api/agenda/modalidades/00000000-0000-0000-0000-000000000099')
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê, não edita e não deleta modalidade da academia B', async () => {
      const academiaA = await createAcademiaFixture(prisma, {
        nome: 'Academia Isolamento A Modalidade E2E',
      });
      const academiaB = await createAcademiaFixture(prisma, {
        nome: 'Academia Isolamento B Modalidade E2E',
      });
      const tokenA = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaA.id);
      const tokenB = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaB.id);

      const modalidadeB = await request(app.getHttpServer())
        .post('/api/agenda/modalidades')
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ nome: 'Modalidade da B' })
        .expect(201);

      await request(app.getHttpServer())
        .get(`/api/agenda/modalidades/${modalidadeB.body.id}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(404);

      await request(app.getHttpServer())
        .patch(`/api/agenda/modalidades/${modalidadeB.body.id}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ nome: 'Hackeada' })
        .expect(404);

      await request(app.getHttpServer())
        .delete(`/api/agenda/modalidades/${modalidadeB.body.id}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(404);

      const listaA = await request(app.getHttpServer())
        .get('/api/agenda/modalidades')
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(200);
      expect(
        listaA.body.items.some((m: { id: string }) => m.id === modalidadeB.body.id),
      ).toBe(false);
    });
  });

  describe('Pesquisa e paginação', () => {
    it('pesquisa por nome', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Pesquisa Modalidade E2E',
      });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .post('/api/agenda/modalidades')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Pilates Pesquisável' })
        .expect(201);

      const porNome = await request(app.getHttpServer())
        .get('/api/agenda/modalidades?search=Pesquisável')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(porNome.body.total).toBeGreaterThanOrEqual(1);

      const semResultado = await request(app.getHttpServer())
        .get('/api/agenda/modalidades?search=NomeQueNaoExisteInventadoXYZ')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(semResultado.body.total).toBe(0);
    });
  });

  describe('Soft delete', () => {
    it('DELETE não remove fisicamente — some da listagem mas continua no banco com deletedAt', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Soft Delete Modalidade E2E',
      });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      const criada = await request(app.getHttpServer())
        .post('/api/agenda/modalidades')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Modalidade Será Removida' })
        .expect(201);

      await request(app.getHttpServer())
        .delete(`/api/agenda/modalidades/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(204);

      await request(app.getHttpServer())
        .get(`/api/agenda/modalidades/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(404);

      const linhaNoBanco = await prisma.modalidade.findUnique({ where: { id: criada.body.id } });
      expect(linhaNoBanco).not.toBeNull();
      expect(linhaNoBanco?.deletedAt).not.toBeNull();

      const deleteAudit = await prisma.auditLog.findFirst({
        where: { action: 'MODALIDADE_DELETED', academiaId: academia.id },
      });
      expect(deleteAudit).not.toBeNull();
    });
  });
});
