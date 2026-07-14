import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import {
  createAcademiaFixture,
  createModalidadeFixture,
  createProfessorFixture,
} from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

const SENHA = 'SenhaForte123';

describe('Turmas (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string): Promise<string> {
    const email = `${role.toLowerCase()}-turmas-${Date.now()}-${Math.random()}@example.com`;
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

  /// Academia + token + modalidade + professor reais, prontos pra criar
  /// uma Turma — mesmo padrão de cenarioBase já usado em Mensalidades.
  async function cenarioBase(nomeAcademia: string) {
    const academia = await createAcademiaFixture(prisma, { nome: nomeAcademia });
    const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    const modalidade = await createModalidadeFixture(prisma, academia.id);
    const professor = await createProfessorFixture(prisma, academia.id);
    return { academia, token, modalidade, professor };
  }

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('sem token -> 401', async () => {
    await request(app.getHttpServer()).get('/api/agenda/turmas').expect(401);
  });

  it('PROFESSOR não tem acesso (403)', async () => {
    const academia = await createAcademiaFixture(prisma, {
      nome: 'Academia Professor Sem Acesso Turma E2E',
    });
    const token = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    await request(app.getHttpServer())
      .get('/api/agenda/turmas')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  describe('CRUD', () => {
    it('ACADEMIA_ADMIN cria, lista, detalha, edita e ativa/inativa uma turma', async () => {
      const { academia, token, modalidade, professor } = await cenarioBase(
        'Academia CRUD Turma E2E',
      );

      const criada = await request(app.getHttpServer())
        .post('/api/agenda/turmas')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Funcional 7h',
          modalidadeId: modalidade.id,
          professorId: professor.id,
          capacidadeMaxima: 15,
          local: 'Sala 2',
        })
        .expect(201);
      expect(criada.body.status).toBe('ATIVO');
      expect(criada.body.modalidadeNome).toBe(modalidade.nome);
      expect(criada.body.professorNome).toBe(professor.nome);
      expect(criada.body.capacidadeMaxima).toBe(15);

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'TURMA_CREATED', academiaId: academia.id },
      });
      expect(auditEntry).not.toBeNull();
      expect(auditEntry?.ipAddress).toBeTruthy();

      const detalhe = await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(detalhe.body.nome).toBe('Funcional 7h');

      const editada = await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ capacidadeMaxima: 20 })
        .expect(200);
      expect(editada.body.capacidadeMaxima).toBe(20);

      const inativada = await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${criada.body.id}/status`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'INATIVO', motivo: 'Turma descontinuada' })
        .expect(200);
      expect(inativada.body.status).toBe('INATIVO');

      const statusAudit = await prisma.auditLog.findFirst({
        where: { action: 'TURMA_STATUS_CHANGED', academiaId: academia.id },
      });
      expect(statusAudit?.metadata).toMatchObject({
        statusNovo: 'INATIVO',
        motivo: 'Turma descontinuada',
      });
    });

    it('capacidadeMaxima nula é aceita (ilimitada)', async () => {
      const { token, modalidade, professor } = await cenarioBase(
        'Academia Capacidade Ilimitada Turma E2E',
      );

      const criada = await request(app.getHttpServer())
        .post('/api/agenda/turmas')
        .set('Authorization', `Bearer ${token}`)
        .send({ nome: 'Musculação Livre', modalidadeId: modalidade.id, professorId: professor.id })
        .expect(201);

      expect(criada.body.capacidadeMaxima).toBeNull();
    });

    it('modalidadeId inexistente -> 404', async () => {
      const { token, professor } = await cenarioBase('Academia Modalidade Inexistente Turma E2E');

      // @IsUUID() (sem versão) exige um nibble de versão válido (1-5) — o
      // "00000000-0000-0000-..." usado como id inexistente em outros specs
      // passa pelo ParseUUIDPipe (rota), mas é rejeitado aqui como 400
      // antes mesmo de chegar ao service. UUID versão 4 bem formado, só
      // que inexistente no banco.
      await request(app.getHttpServer())
        .post('/api/agenda/turmas')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Turma Ruim',
          modalidadeId: '00000000-0000-4000-8000-000000000099',
          professorId: professor.id,
        })
        .expect(404);
    });

    it('professorId inexistente -> 404', async () => {
      const { token, modalidade } = await cenarioBase('Academia Professor Inexistente Turma E2E');

      await request(app.getHttpServer())
        .post('/api/agenda/turmas')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Turma Ruim',
          modalidadeId: modalidade.id,
          professorId: '00000000-0000-4000-8000-000000000099',
        })
        .expect(404);
    });

    it('modalidade de outra academia não pode ser referenciada (404 — isolamento na validação de FK)', async () => {
      const cenarioA = await cenarioBase('Academia Turma Cross Tenant A E2E');
      const cenarioB = await cenarioBase('Academia Turma Cross Tenant B E2E');

      await request(app.getHttpServer())
        .post('/api/agenda/turmas')
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({
          nome: 'Turma Cross Tenant',
          modalidadeId: cenarioB.modalidade.id,
          professorId: cenarioA.professor.id,
        })
        .expect(404);
    });

    it('duas turmas com o mesmo nome na mesma academia são permitidas', async () => {
      const { token, modalidade, professor } = await cenarioBase(
        'Academia Nome Repetido Turma E2E',
      );
      const payload = {
        nome: 'Funcional',
        modalidadeId: modalidade.id,
        professorId: professor.id,
      };

      await request(app.getHttpServer())
        .post('/api/agenda/turmas')
        .set('Authorization', `Bearer ${token}`)
        .send(payload)
        .expect(201);

      await request(app.getHttpServer())
        .post('/api/agenda/turmas')
        .set('Authorization', `Bearer ${token}`)
        .send(payload)
        .expect(201);
    });

    it('id inexistente -> 404', async () => {
      const { token } = await cenarioBase('Academia 404 Turma E2E');

      await request(app.getHttpServer())
        .get('/api/agenda/turmas/00000000-0000-0000-0000-000000000099')
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê, não edita e não deleta turma da academia B', async () => {
      const cenarioA = await cenarioBase('Academia Isolamento A Turma E2E');
      const cenarioB = await cenarioBase('Academia Isolamento B Turma E2E');

      const turmaB = await request(app.getHttpServer())
        .post('/api/agenda/turmas')
        .set('Authorization', `Bearer ${cenarioB.token}`)
        .send({
          nome: 'Turma da B',
          modalidadeId: cenarioB.modalidade.id,
          professorId: cenarioB.professor.id,
        })
        .expect(201);

      await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${turmaB.body.id}`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(404);

      await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${turmaB.body.id}`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({ nome: 'Hackeada' })
        .expect(404);

      await request(app.getHttpServer())
        .delete(`/api/agenda/turmas/${turmaB.body.id}`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(404);

      const listaA = await request(app.getHttpServer())
        .get('/api/agenda/turmas')
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(200);
      expect(listaA.body.items.some((t: { id: string }) => t.id === turmaB.body.id)).toBe(false);
    });
  });

  describe('Pesquisa e paginação', () => {
    it('pesquisa por nome', async () => {
      const { token, modalidade, professor } = await cenarioBase('Academia Pesquisa Turma E2E');

      await request(app.getHttpServer())
        .post('/api/agenda/turmas')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Spinning Pesquisável',
          modalidadeId: modalidade.id,
          professorId: professor.id,
        })
        .expect(201);

      const porNome = await request(app.getHttpServer())
        .get('/api/agenda/turmas?search=Pesquisável')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(porNome.body.total).toBeGreaterThanOrEqual(1);

      const semResultado = await request(app.getHttpServer())
        .get('/api/agenda/turmas?search=NomeQueNaoExisteInventadoXYZ')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(semResultado.body.total).toBe(0);
    });
  });

  describe('Soft delete', () => {
    it('DELETE não remove fisicamente — some da listagem mas continua no banco com deletedAt', async () => {
      const { academia, token, modalidade, professor } = await cenarioBase(
        'Academia Soft Delete Turma E2E',
      );

      const criada = await request(app.getHttpServer())
        .post('/api/agenda/turmas')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Turma Será Removida',
          modalidadeId: modalidade.id,
          professorId: professor.id,
        })
        .expect(201);

      await request(app.getHttpServer())
        .delete(`/api/agenda/turmas/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(204);

      await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${criada.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(404);

      const linhaNoBanco = await prisma.turma.findUnique({ where: { id: criada.body.id } });
      expect(linhaNoBanco).not.toBeNull();
      expect(linhaNoBanco?.deletedAt).not.toBeNull();

      const deleteAudit = await prisma.auditLog.findFirst({
        where: { action: 'TURMA_DELETED', academiaId: academia.id },
      });
      expect(deleteAudit).not.toBeNull();
    });
  });
});
