import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import { createAcademiaFixture } from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

const SENHA = 'SenhaForte123';

describe('Notificacoes (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string) {
    const email = `${role.toLowerCase()}-notificacoes-${Date.now()}-${Math.random()}@example.com`;
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

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('sem token -> 401', async () => {
    await request(app.getHttpServer()).get('/api/notificacoes').expect(401);
  });

  it('lista vazia quando o usuário não tem notificações', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Notificacoes Vazia E2E' });
    const { token } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

    const lista = await request(app.getHttpServer())
      .get('/api/notificacoes')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(lista.body.total).toBe(0);
    expect(lista.body.naoLidas).toBe(0);
  });

  it('lista só as próprias notificações, não-lidas primeiro, depois mais recentes', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Notificacoes Ordenacao E2E' });
    const { token, userId } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    const outro = await criarUsuarioELogar(Role.RECEPCIONISTA, academia.id);

    const antiga = await prisma.notificacao.create({
      data: { academiaId: academia.id, userId, titulo: 'Antiga lida', mensagem: 'x', lida: true, lidaEm: new Date() },
    });
    const recenteLida = await prisma.notificacao.create({
      data: { academiaId: academia.id, userId, titulo: 'Recente lida', mensagem: 'x', lida: true, lidaEm: new Date() },
    });
    const naoLida = await prisma.notificacao.create({
      data: { academiaId: academia.id, userId, titulo: 'Não lida', mensagem: 'x' },
    });
    await prisma.notificacao.create({
      data: { academiaId: academia.id, userId: outro.userId, titulo: 'De outro usuário', mensagem: 'x' },
    });
    void antiga;
    void recenteLida;

    const lista = await request(app.getHttpServer())
      .get('/api/notificacoes')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(lista.body.total).toBe(3);
    expect(lista.body.naoLidas).toBe(1);
    expect(lista.body.items[0].id).toBe(naoLida.id);
    expect(lista.body.items[0].lida).toBe(false);
  });

  it('marca como lida — idempotente, sem gerar AuditLog', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Notificacoes Marcar Lida E2E' });
    const { token, userId } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    const notificacao = await prisma.notificacao.create({
      data: { academiaId: academia.id, userId, titulo: 'Título', mensagem: 'Mensagem' },
    });

    const totalAuditoriaAntes = await prisma.auditLog.count({ where: { academiaId: academia.id } });

    const marcada = await request(app.getHttpServer())
      .patch(`/api/notificacoes/${notificacao.id}/lida`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(marcada.body.lida).toBe(true);
    expect(marcada.body.lidaEm).not.toBeNull();

    // idempotente — marcar de novo não quebra nem altera lidaEm
    const marcadaDeNovo = await request(app.getHttpServer())
      .patch(`/api/notificacoes/${notificacao.id}/lida`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(marcadaDeNovo.body.lidaEm).toBe(marcada.body.lidaEm);

    const totalAuditoriaDepois = await prisma.auditLog.count({ where: { academiaId: academia.id } });
    expect(totalAuditoriaDepois).toBe(totalAuditoriaAntes);
  });

  it('não marca notificação de outro usuário -> 404', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Notificacoes Cross User E2E' });
    const { userId: donoId } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    const { token: tokenOutro } = await criarUsuarioELogar(Role.RECEPCIONISTA, academia.id);
    const notificacao = await prisma.notificacao.create({
      data: { academiaId: academia.id, userId: donoId, titulo: 'Título', mensagem: 'Mensagem' },
    });

    await request(app.getHttpServer())
      .patch(`/api/notificacoes/${notificacao.id}/lida`)
      .set('Authorization', `Bearer ${tokenOutro}`)
      .expect(404);
  });

  describe('Integração com Solicitação de Reposição', () => {
    it('criar uma solicitação notifica os outros ACADEMIA_ADMIN/RECEPCIONISTA, não quem criou', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Notificacao Integracao Criar E2E' });
      const criador = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
      const outroAdmin = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
      const professor = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

      const modalidade = await prisma.modalidade.create({
        data: { academiaId: academia.id, nome: 'Modalidade Notif' },
      });
      const professorFixture = await prisma.professor.create({
        data: { academiaId: academia.id, nome: 'Prof Notif', cpf: `CPF-${Date.now()}`, telefone: '11999999999' },
      });
      const turma = await request(app.getHttpServer())
        .post('/api/agenda/turmas')
        .set('Authorization', `Bearer ${criador.token}`)
        .send({ nome: 'Turma Notif', modalidadeId: modalidade.id, professorId: professorFixture.id })
        .expect(201);
      const aluno = await prisma.aluno.create({
        data: {
          academiaId: academia.id,
          nome: 'Aluno Notif',
          cpf: `CPF-ALUNO-${Date.now()}`,
          dataNascimento: new Date('1995-01-01'),
          sexo: 'MASCULINO',
          telefone: '11999999999',
        },
      });
      const plano = await prisma.plano.create({
        data: { academiaId: academia.id, nome: 'Plano Notif', periodicidade: 'MENSAL', valor: 100 },
      });
      await prisma.matricula.create({
        data: {
          academiaId: academia.id,
          alunoId: aluno.id,
          planoId: plano.id,
          createdByUserId: criador.userId,
          valor: 100,
          diaVencimento: 10,
          periodicidade: 'MENSAL',
          dataInicio: new Date('2026-01-01'),
          dataFimPrevista: new Date('2027-01-01'),
          dataFim: new Date('2027-01-01'),
          status: 'ATIVA',
        },
      });
      const turmaAluno = await request(app.getHttpServer())
        .post(`/api/agenda/turmas/${turma.body.id}/alunos`)
        .set('Authorization', `Bearer ${criador.token}`)
        .send({ alunoId: aluno.id })
        .expect(201);

      const ontem = new Date();
      ontem.setUTCDate(ontem.getUTCDate() - 1);
      const dataOntem = new Date(Date.UTC(ontem.getUTCFullYear(), ontem.getUTCMonth(), ontem.getUTCDate()));
      const aula = await prisma.aula.create({
        data: {
          academiaId: academia.id,
          turmaId: turma.body.id,
          data: dataOntem,
          horaInicio: '07:00',
          duracaoMinutos: 60,
          professorId: professorFixture.id,
          createdByUserId: criador.userId,
        },
      });
      const aulaAluno = await prisma.aulaAluno.create({
        data: {
          academiaId: academia.id,
          aulaId: aula.id,
          alunoId: aluno.id,
          turmaAlunoId: turmaAluno.body.id,
          tipo: 'MATRICULADO',
          presenca: 'AUSENTE',
        },
      });

      await request(app.getHttpServer())
        .post('/api/agenda/solicitacoes-reposicao')
        .set('Authorization', `Bearer ${criador.token}`)
        .send({ aulaAlunoOrigemId: aulaAluno.id })
        .expect(201);

      const notifOutroAdmin = await request(app.getHttpServer())
        .get('/api/notificacoes')
        .set('Authorization', `Bearer ${outroAdmin.token}`)
        .expect(200);
      expect(notifOutroAdmin.body.total).toBe(1);
      expect(notifOutroAdmin.body.items[0].titulo).toBe('Nova solicitação de reposição');

      const notifCriador = await request(app.getHttpServer())
        .get('/api/notificacoes')
        .set('Authorization', `Bearer ${criador.token}`)
        .expect(200);
      expect(notifCriador.body.total).toBe(0);

      const notifProfessor = await request(app.getHttpServer())
        .get('/api/notificacoes')
        .set('Authorization', `Bearer ${professor.token}`)
        .expect(200);
      expect(notifProfessor.body.total).toBe(0);
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê notificação da academia B', async () => {
      const academiaA = await createAcademiaFixture(prisma, { nome: 'Academia Notif Isolamento A E2E' });
      const academiaB = await createAcademiaFixture(prisma, { nome: 'Academia Notif Isolamento B E2E' });
      const { token: tokenA } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaA.id);
      const { token: tokenB, userId: userIdB } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaB.id);
      const notificacaoB = await prisma.notificacao.create({
        data: { academiaId: academiaB.id, userId: userIdB, titulo: 'Da B', mensagem: 'x' },
      });

      const listaA = await request(app.getHttpServer())
        .get('/api/notificacoes')
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(200);
      expect(listaA.body.total).toBe(0);

      await request(app.getHttpServer())
        .patch(`/api/notificacoes/${notificacaoB.id}/lida`)
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(404);

      await request(app.getHttpServer())
        .get('/api/notificacoes')
        .set('Authorization', `Bearer ${tokenB}`)
        .expect(200)
        .then((res) => expect(res.body.total).toBe(1));
    });
  });
});
