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

const SENHA = 'SenhaForte123';

describe('TurmaAlunos (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string) {
    const email = `${role.toLowerCase()}-turma-alunos-${Date.now()}-${Math.random()}@example.com`;
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

  /// Academia + token + turma real + um aluno com Matricula ATIVA — pronto
  /// pra inscrever em TurmaAluno. `criarAlunoElegivel` fica à parte porque
  /// vários testes precisam de mais de um aluno elegível no mesmo cenário
  /// (capacidade, duplicidade).
  async function cenarioBase(nomeAcademia: string, capacidadeMaxima?: number) {
    const academia = await createAcademiaFixture(prisma, { nome: nomeAcademia });
    const { token, userId } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    const modalidade = await createModalidadeFixture(prisma, academia.id);
    const professor = await createProfessorFixture(prisma, academia.id);
    const plano = await createPlanoFixture(prisma, academia.id);

    const turma = await request(app.getHttpServer())
      .post('/api/agenda/turmas')
      .set('Authorization', `Bearer ${token}`)
      .send({
        nome: 'Turma Base',
        modalidadeId: modalidade.id,
        professorId: professor.id,
        ...(capacidadeMaxima !== undefined ? { capacidadeMaxima } : {}),
      })
      .expect(201);

    return { academia, token, userId, plano, turma: turma.body };
  }

  async function criarAlunoElegivel(academiaId: string, planoId: string, userId: string) {
    const aluno = await createAlunoFixture(prisma, academiaId);
    await createMatriculaFixture(prisma, academiaId, aluno.id, planoId, userId);
    return aluno;
  }

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('sem token -> 401', async () => {
    const { turma } = await cenarioBase('Academia TurmaAluno Sem Token E2E');
    await request(app.getHttpServer()).get(`/api/agenda/turmas/${turma.id}/alunos`).expect(401);
  });

  it('PROFESSOR não tem acesso (403)', async () => {
    const { turma, academia } = await cenarioBase('Academia TurmaAluno Professor Sem Acesso E2E');
    const { token: tokenProfessor } = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    await request(app.getHttpServer())
      .get(`/api/agenda/turmas/${turma.id}/alunos`)
      .set('Authorization', `Bearer ${tokenProfessor}`)
      .expect(403);
  });

  describe('CRUD', () => {
    it('ACADEMIA_ADMIN inscreve, lista, tira e reinscreve um aluno', async () => {
      const { academia, token, userId, plano, turma } = await cenarioBase(
        'Academia CRUD TurmaAluno E2E',
      );
      const aluno = await criarAlunoElegivel(academia.id, plano.id, userId);

      const inscrito = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id })
        .expect(201);
      expect(inscrito.body.turmaId).toBe(turma.id);
      expect(inscrito.body.alunoId).toBe(aluno.id);
      expect(inscrito.body.alunoNome).toBe(aluno.nome);
      expect(inscrito.body.status).toBe('ATIVO');

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'TURMA_ALUNO_MATRICULADO', academiaId: academia.id },
      });
      expect(auditEntry).not.toBeNull();

      const lista = await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(lista.body).toHaveLength(1);

      // Sai da turma (status INATIVO — encerramento de negócio, não deletedAt).
      const saiu = await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${turma.id}/alunos/${inscrito.body.id}/status`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'INATIVO', motivo: 'Trancou a matrícula' })
        .expect(200);
      expect(saiu.body.status).toBe('INATIVO');
      expect(saiu.body.dataFim).not.toBeNull();

      const statusAudit = await prisma.auditLog.findFirst({
        where: { action: 'TURMA_ALUNO_STATUS_CHANGED', academiaId: academia.id },
      });
      expect(statusAudit?.metadata).toMatchObject({ statusNovo: 'INATIVO' });

      // Reativa a mesma linha.
      const reativado = await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${turma.id}/alunos/${inscrito.body.id}/status`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'ATIVO' })
        .expect(200);
      expect(reativado.body.status).toBe('ATIVO');
      expect(reativado.body.dataFim).toBeNull();
    });

    it('aluno sem matrícula ativa -> 400', async () => {
      const { academia, token, turma } = await cenarioBase('Academia Sem Matricula Ativa E2E');
      const aluno = await createAlunoFixture(prisma, academia.id);

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id })
        .expect(400);
    });

    it('aluno já inscrito (ATIVO) na mesma turma -> 409', async () => {
      const { academia, token, userId, plano, turma } = await cenarioBase(
        'Academia Duplicidade TurmaAluno E2E',
      );
      const aluno = await criarAlunoElegivel(academia.id, plano.id, userId);

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id })
        .expect(201);

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id })
        .expect(409);
    });

    it('reinscrição depois de sair cria uma nova linha (sem constraint bloqueando)', async () => {
      const { academia, token, userId, plano, turma } = await cenarioBase(
        'Academia Reinscricao TurmaAluno E2E',
      );
      const aluno = await criarAlunoElegivel(academia.id, plano.id, userId);

      const primeira = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${turma.id}/alunos/${primeira.body.id}/status`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'INATIVO' })
        .expect(200);

      const segunda = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id })
        .expect(201);
      expect(segunda.body.id).not.toBe(primeira.body.id);

      const lista = await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(lista.body).toHaveLength(2);
    });

    it('capacidade máxima atingida -> 409, aluno excedente bloqueado', async () => {
      const { academia, token, userId, plano, turma } = await cenarioBase(
        'Academia Capacidade TurmaAluno E2E',
        1,
      );
      const aluno1 = await criarAlunoElegivel(academia.id, plano.id, userId);
      const aluno2 = await criarAlunoElegivel(academia.id, plano.id, userId);

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno1.id })
        .expect(201);

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno2.id })
        .expect(409);
    });

    it('capacidadeMaxima nula é ilimitada — sem bloqueio', async () => {
      const { academia, token, userId, plano, turma } = await cenarioBase(
        'Academia Capacidade Ilimitada TurmaAluno E2E',
      );
      const aluno1 = await criarAlunoElegivel(academia.id, plano.id, userId);
      const aluno2 = await criarAlunoElegivel(academia.id, plano.id, userId);

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno1.id })
        .expect(201);
      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno2.id })
        .expect(201);
    });

    it('turmaId inexistente -> 404', async () => {
      const { academia, token, userId, plano } = await cenarioBase(
        'Academia Turma Inexistente TurmaAluno E2E',
      );
      const aluno = await criarAlunoElegivel(academia.id, plano.id, userId);

      await request(app.getHttpServer())
        .post('/api/agenda/turmas/00000000-0000-4000-8000-000000000099/alunos')
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id })
        .expect(404);
    });

    it('alunoId inexistente -> 404', async () => {
      const { token, turma } = await cenarioBase('Academia Aluno Inexistente TurmaAluno E2E');

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: '00000000-0000-4000-8000-000000000099' })
        .expect(404);
    });

    it('aluno de outra academia não pode ser inscrito (404)', async () => {
      const cenarioA = await cenarioBase('Academia TurmaAluno Cross Tenant A E2E');
      const cenarioB = await cenarioBase('Academia TurmaAluno Cross Tenant B E2E');
      const alunoB = await criarAlunoElegivel(cenarioB.academia.id, cenarioB.plano.id, cenarioB.userId);

      await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${cenarioA.turma.id}/alunos`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({ alunoId: alunoB.id })
        .expect(404);
    });

    it('id inexistente -> 404', async () => {
      const { token, turma } = await cenarioBase('Academia 404 TurmaAluno E2E');

      await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${turma.id}/alunos/00000000-0000-0000-0000-000000000099/status`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'INATIVO' })
        .expect(404);
    });
  });

  describe('Invariante — TurmaAluno nunca cria/altera/remove AulaAluno (MS5)', () => {
    it('inscrever, ativar/inativar e remover TurmaAluno não gera nenhuma linha de AulaAluno', async () => {
      const { academia, token, userId, plano, turma } = await cenarioBase(
        'Academia Invariante AulaAluno E2E',
      );
      const aluno = await criarAlunoElegivel(academia.id, plano.id, userId);

      const inscrito = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${turma.id}/alunos/${inscrito.body.id}/status`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'INATIVO' })
        .expect(200);

      await request(app.getHttpServer())
        .delete(`/api/agenda/turmas/${turma.id}/alunos/${inscrito.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(204);

      const totalAulaAluno = await prisma.aulaAluno.count({ where: { turmaAlunoId: inscrito.body.id } });
      expect(totalAulaAluno).toBe(0);
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê, não altera e não deleta inscrição da academia B', async () => {
      const cenarioA = await cenarioBase('Academia Isolamento TurmaAluno A E2E');
      const cenarioB = await cenarioBase('Academia Isolamento TurmaAluno B E2E');
      const alunoB = await criarAlunoElegivel(cenarioB.academia.id, cenarioB.plano.id, cenarioB.userId);

      const inscritoB = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${cenarioB.turma.id}/alunos`)
        .set('Authorization', `Bearer ${cenarioB.token}`)
        .send({ alunoId: alunoB.id })
        .expect(201);

      await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${cenarioB.turma.id}/alunos`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(404);

      await request(app.getHttpServer())
        .patch(`/api/agenda/turmas/${cenarioB.turma.id}/alunos/${inscritoB.body.id}/status`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({ status: 'INATIVO' })
        .expect(404);

      await request(app.getHttpServer())
        .delete(`/api/agenda/turmas/${cenarioB.turma.id}/alunos/${inscritoB.body.id}`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(404);
    });
  });

  describe('Soft delete', () => {
    it('DELETE não remove fisicamente — some da listagem mas continua no banco com deletedAt', async () => {
      const { academia, token, userId, plano, turma } = await cenarioBase(
        'Academia Soft Delete TurmaAluno E2E',
      );
      const aluno = await criarAlunoElegivel(academia.id, plano.id, userId);

      const inscrito = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .send({ alunoId: aluno.id })
        .expect(201);

      await request(app.getHttpServer())
        .delete(`/api/agenda/turmas/${turma.id}/alunos/${inscrito.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(204);

      const lista = await request(app.getHttpServer())
        .get(`/api/agenda/turmas/${turma.id}/alunos`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(lista.body).toHaveLength(0);

      const linhaNoBanco = await prisma.turmaAluno.findUnique({ where: { id: inscrito.body.id } });
      expect(linhaNoBanco).not.toBeNull();
      expect(linhaNoBanco?.deletedAt).not.toBeNull();

      const deleteAudit = await prisma.auditLog.findFirst({
        where: { action: 'TURMA_ALUNO_REMOVIDO', academiaId: academia.id },
      });
      expect(deleteAudit).not.toBeNull();
    });
  });
});
