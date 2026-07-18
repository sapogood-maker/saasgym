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

describe('Aulas Calendario (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string) {
    const email = `${role.toLowerCase()}-aulas-cal-${Date.now()}-${Math.random()}@example.com`;
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

  /// Academia + token + turma + 1 recorrência SEMANAL + 1 Aula já gerada
  /// (segunda-feira 03/08/2026) — pronto pra cancelar/substituir.
  async function cenarioComAula(nomeAcademia: string, local?: string) {
    const academia = await createAcademiaFixture(prisma, { nome: nomeAcademia });
    const { token, userId } = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
    const modalidade = await createModalidadeFixture(prisma, academia.id);
    const professor = await createProfessorFixture(prisma, academia.id);

    const turma = await request(app.getHttpServer())
      .post('/api/agenda/turmas')
      .set('Authorization', `Bearer ${token}`)
      .send({
        nome: 'Turma Calendário',
        modalidadeId: modalidade.id,
        professorId: professor.id,
        local,
      })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/agenda/turmas/${turma.body.id}/recorrencias`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        tipo: 'SEMANAL',
        diaSemana: 1,
        horaInicio: '07:00',
        duracaoMinutos: 60,
        dataInicioVigencia: '2026-08-01',
      })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/agenda/turmas/${turma.body.id}/aulas/gerar`)
      .set('Authorization', `Bearer ${token}`)
      .send({ dataInicio: '2026-08-01', dataFim: '2026-08-31' })
      .expect(201);

    const lista = await request(app.getHttpServer())
      .get(`/api/agenda/turmas/${turma.body.id}/aulas`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    return {
      academia,
      token,
      userId,
      modalidade,
      professor,
      turma: turma.body,
      aula: lista.body.items[0],
    };
  }

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('sem token -> 401', async () => {
    await request(app.getHttpServer()).get('/api/agenda/aulas').expect(401);
  });

  it('PROFESSOR não tem acesso (403)', async () => {
    const academia = await createAcademiaFixture(prisma, {
      nome: 'Academia Calendario Prof Sem Acesso E2E',
    });
    const { token } = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    await request(app.getHttpServer())
      .get('/api/agenda/aulas')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  describe('Cancelar', () => {
    it('cancela a aula — status muda, histórico permanece íntegro (aparece na listagem)', async () => {
      const { academia, token, aula } = await cenarioComAula('Academia Cancelar Aula E2E');

      const cancelada = await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${aula.id}/cancelar`)
        .set('Authorization', `Bearer ${token}`)
        .send({ motivoCancelamento: 'Feriado municipal' })
        .expect(200);
      expect(cancelada.body.status).toBe('CANCELADA');
      expect(cancelada.body.motivoCancelamento).toBe('Feriado municipal');

      const linhaNoBanco = await prisma.aula.findUnique({ where: { id: aula.id } });
      expect(linhaNoBanco?.deletedAt).toBeNull();

      const naListagem = await request(app.getHttpServer())
        .get(`/api/agenda/aulas?turmaId=${aula.turmaId}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(naListagem.body.items.some((a: { id: string }) => a.id === aula.id)).toBe(true);

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'AULA_CANCELADA', academiaId: academia.id },
      });
      expect(auditEntry?.metadata).toMatchObject({
        aulaId: aula.id,
        motivoCancelamento: 'Feriado municipal',
      });
    });

    it('id inexistente -> 404', async () => {
      const { token } = await cenarioComAula('Academia Cancelar 404 E2E');

      await request(app.getHttpServer())
        .patch('/api/agenda/aulas/00000000-0000-0000-0000-000000000099/cancelar')
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(404);
    });
  });

  describe('Professor substituto', () => {
    it('define substituto — só Aula.professorId muda, Turma/Recorrencia continuam com o titular', async () => {
      const { academia, token, professor, turma, aula } =
        await cenarioComAula('Academia Substituto E2E');
      const substituto = await createProfessorFixture(prisma, academia.id);

      const atualizada = await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${aula.id}/substituto`)
        .set('Authorization', `Bearer ${token}`)
        .send({ professorId: substituto.id })
        .expect(200);
      expect(atualizada.body.professorId).toBe(substituto.id);

      const turmaAtual = await prisma.turma.findUniqueOrThrow({ where: { id: turma.id } });
      expect(turmaAtual.professorId).toBe(professor.id);

      const recorrenciaAtual = await prisma.recorrencia.findFirstOrThrow({
        where: { turmaId: turma.id },
      });
      expect(recorrenciaAtual.professorId).toBeNull();

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'AULA_SUBSTITUICAO', academiaId: academia.id },
      });
      expect(auditEntry?.metadata).toMatchObject({
        aulaId: aula.id,
        professorTitularId: professor.id,
        professorSubstitutoId: substituto.id,
      });
    });

    it('professorId inexistente -> 404', async () => {
      const { token, aula } = await cenarioComAula('Academia Substituto Inexistente E2E');

      await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${aula.id}/substituto`)
        .set('Authorization', `Bearer ${token}`)
        .send({ professorId: '00000000-0000-4000-8000-000000000099' })
        .expect(404);
    });

    it('professor de outra academia -> 404', async () => {
      const cenarioA = await cenarioComAula('Academia Substituto Cross Tenant A E2E');
      const cenarioB = await cenarioComAula('Academia Substituto Cross Tenant B E2E');

      await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${cenarioA.aula.id}/substituto`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({ professorId: cenarioB.professor.id })
        .expect(404);
    });

    it('não permite definir substituto numa aula cancelada -> 400', async () => {
      const { token, academia, aula } = await cenarioComAula('Academia Substituto Cancelada E2E');
      const substituto = await createProfessorFixture(prisma, academia.id);

      await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${aula.id}/cancelar`)
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(200);

      await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${aula.id}/substituto`)
        .set('Authorization', `Bearer ${token}`)
        .send({ professorId: substituto.id })
        .expect(400);
    });
  });

  describe('Aula extra', () => {
    it('cria aula extra com recorrenciaId nulo e snapshot da turma', async () => {
      const { academia, token, professor, turma } = await cenarioComAula('Academia Aula Extra E2E');

      const extra = await request(app.getHttpServer())
        .post('/api/agenda/aulas/extra')
        .set('Authorization', `Bearer ${token}`)
        .send({ turmaId: turma.id, data: '2026-08-20', horaInicio: '18:00', duracaoMinutos: 45 })
        .expect(201);
      expect(extra.body.recorrenciaId).toBeNull();
      expect(extra.body.professorId).toBe(professor.id);
      expect(extra.body.totalAlunos).toBe(0);

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'AULA_EXTRA_CRIADA', academiaId: academia.id },
      });
      expect(auditEntry?.metadata).toMatchObject({ aulaId: extra.body.id, turmaId: turma.id });
    });

    it('aceita override de professor e capacidade', async () => {
      const { academia, token, turma } = await cenarioComAula('Academia Aula Extra Override E2E');
      const outroProfessor = await createProfessorFixture(prisma, academia.id);

      const extra = await request(app.getHttpServer())
        .post('/api/agenda/aulas/extra')
        .set('Authorization', `Bearer ${token}`)
        .send({
          turmaId: turma.id,
          data: '2026-08-21',
          horaInicio: '18:00',
          duracaoMinutos: 45,
          professorId: outroProfessor.id,
          capacidadeMaxima: 10,
        })
        .expect(201);
      expect(extra.body.professorId).toBe(outroProfessor.id);
      expect(extra.body.capacidadeMaxima).toBe(10);
    });

    it('não cria nem altera Recorrencia da turma', async () => {
      const { token, turma } = await cenarioComAula('Academia Aula Extra Sem Recorrencia E2E');

      const recorrenciasAntes = await prisma.recorrencia.count({ where: { turmaId: turma.id } });
      await request(app.getHttpServer())
        .post('/api/agenda/aulas/extra')
        .set('Authorization', `Bearer ${token}`)
        .send({ turmaId: turma.id, data: '2026-08-22', horaInicio: '18:00', duracaoMinutos: 45 })
        .expect(201);
      const recorrenciasDepois = await prisma.recorrencia.count({ where: { turmaId: turma.id } });

      expect(recorrenciasDepois).toBe(recorrenciasAntes);
    });

    it('turmaId inexistente -> 404', async () => {
      const { token } = await cenarioComAula('Academia Aula Extra Turma Inexistente E2E');

      await request(app.getHttpServer())
        .post('/api/agenda/aulas/extra')
        .set('Authorization', `Bearer ${token}`)
        .send({
          turmaId: '00000000-0000-4000-8000-000000000099',
          data: '2026-08-20',
          horaInicio: '18:00',
          duracaoMinutos: 45,
        })
        .expect(404);
    });
  });

  describe('Listagem — filtros do Calendário', () => {
    it('filtra por período, turma, professor, modalidade e status', async () => {
      const { token, turma, professor, modalidade, aula } = await cenarioComAula(
        'Academia Filtros Calendario E2E',
      );

      const porPeriodo = await request(app.getHttpServer())
        .get('/api/agenda/aulas?dataInicio=2026-08-01&dataFim=2026-08-31')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(porPeriodo.body.total).toBeGreaterThanOrEqual(1);

      const porTurma = await request(app.getHttpServer())
        .get(`/api/agenda/aulas?turmaId=${turma.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(porTurma.body.items.every((a: { turmaId: string }) => a.turmaId === turma.id)).toBe(
        true,
      );

      const porProfessor = await request(app.getHttpServer())
        .get(`/api/agenda/aulas?professorId=${professor.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(
        porProfessor.body.items.every(
          (a: { professorId: string }) => a.professorId === professor.id,
        ),
      ).toBe(true);

      const porModalidade = await request(app.getHttpServer())
        .get(`/api/agenda/aulas?modalidadeId=${modalidade.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(porModalidade.body.total).toBeGreaterThanOrEqual(1);

      await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${aula.id}/cancelar`)
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(200);

      const porStatus = await request(app.getHttpServer())
        .get('/api/agenda/aulas?status=CANCELADA')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(porStatus.body.items.some((a: { id: string }) => a.id === aula.id)).toBe(true);

      const porStatusAgendada = await request(app.getHttpServer())
        .get(`/api/agenda/aulas?status=AGENDADA&turmaId=${turma.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(porStatusAgendada.body.items.some((a: { id: string }) => a.id === aula.id)).toBe(
        false,
      );
    });
  });

  /// Sprint de UX da Agenda (docs/24, item 6) — `totalReposicoes` e `local`
  /// no `AulaResponseDto`, pro resumo operacional e pro chip da Semana.
  describe('Campos novos — totalReposicoes e local', () => {
    it('totalReposicoes conta só AulaAluno com tipo REPOSICAO; local reflete Turma.local', async () => {
      const { academia, token, turma, aula } = await cenarioComAula(
        'Academia Campos Novos Calendario E2E',
        'Tatame',
      );
      const aluno1 = await createAlunoFixture(prisma, academia.id);
      const aluno2 = await createAlunoFixture(prisma, academia.id);

      await prisma.aulaAluno.create({
        data: { academiaId: academia.id, aulaId: aula.id, alunoId: aluno1.id, tipo: 'MATRICULADO' },
      });
      await prisma.aulaAluno.create({
        data: { academiaId: academia.id, aulaId: aula.id, alunoId: aluno2.id, tipo: 'REPOSICAO' },
      });

      const res = await request(app.getHttpServer())
        .get(`/api/agenda/aulas?turmaId=${turma.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      const aulaAtualizada = res.body.items.find((a: { id: string }) => a.id === aula.id);
      expect(aulaAtualizada.totalAlunos).toBe(2);
      expect(aulaAtualizada.totalReposicoes).toBe(1);
      expect(aulaAtualizada.local).toBe('Tatame');
    });

    it('local vem nulo quando a Turma não tem local definido', async () => {
      const { token, turma } = await cenarioComAula('Academia Sem Local Calendario E2E');

      const res = await request(app.getHttpServer())
        .get(`/api/agenda/aulas?turmaId=${turma.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.items[0].local).toBeNull();
    });
  });

  describe('incluirAlunos — Agenda operacional (docs/33)', () => {
    it('sem incluirAlunos (padrão) -> alunosNomes vem vazio mesmo com alunos na aula', async () => {
      const { academia, token, turma, aula } = await cenarioComAula(
        'Academia IncluirAlunos Default E2E',
      );
      const aluno = await createAlunoFixture(prisma, academia.id);
      await prisma.aulaAluno.create({
        data: { academiaId: academia.id, aulaId: aula.id, alunoId: aluno.id, tipo: 'MATRICULADO' },
      });

      const res = await request(app.getHttpServer())
        .get(`/api/agenda/aulas?turmaId=${turma.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      const aulaAtualizada = res.body.items.find((a: { id: string }) => a.id === aula.id);
      expect(aulaAtualizada.totalAlunos).toBe(1);
      expect(aulaAtualizada.alunosNomes).toEqual([]);
    });

    it('incluirAlunos=true -> alunosNomes traz os nomes ordenados, na MESMA consulta (sem round-trip extra)', async () => {
      const { academia, token, turma, aula } = await cenarioComAula(
        'Academia IncluirAlunos True E2E',
      );
      const alunoZ = await createAlunoFixture(prisma, academia.id, { nome: 'Zeca Pagodinho' });
      const alunoA = await createAlunoFixture(prisma, academia.id, { nome: 'Ana Beatriz' });
      await prisma.aulaAluno.create({
        data: { academiaId: academia.id, aulaId: aula.id, alunoId: alunoZ.id, tipo: 'MATRICULADO' },
      });
      await prisma.aulaAluno.create({
        data: { academiaId: academia.id, aulaId: aula.id, alunoId: alunoA.id, tipo: 'REPOSICAO' },
      });

      const res = await request(app.getHttpServer())
        .get(`/api/agenda/aulas?turmaId=${turma.id}&incluirAlunos=true`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      const aulaAtualizada = res.body.items.find((a: { id: string }) => a.id === aula.id);
      expect(aulaAtualizada.totalAlunos).toBe(2);
      expect(aulaAtualizada.totalReposicoes).toBe(1);
      expect(aulaAtualizada.alunosNomes).toEqual(['Ana Beatriz', 'Zeca Pagodinho']);
    });

    it('incluirAlunos=true -> aluno removido (soft delete) não aparece em alunosNomes', async () => {
      const { academia, token, turma, aula } = await cenarioComAula(
        'Academia IncluirAlunos SoftDelete E2E',
      );
      const alunoAtivo = await createAlunoFixture(prisma, academia.id, { nome: 'Aluno Ativo' });
      const alunoRemovido = await createAlunoFixture(prisma, academia.id, {
        nome: 'Aluno Removido',
      });
      await prisma.aulaAluno.create({
        data: {
          academiaId: academia.id,
          aulaId: aula.id,
          alunoId: alunoAtivo.id,
          tipo: 'MATRICULADO',
        },
      });
      await prisma.aulaAluno.create({
        data: {
          academiaId: academia.id,
          aulaId: aula.id,
          alunoId: alunoRemovido.id,
          tipo: 'MATRICULADO',
          deletedAt: new Date(),
        },
      });

      const res = await request(app.getHttpServer())
        .get(`/api/agenda/aulas?turmaId=${turma.id}&incluirAlunos=true`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      const aulaAtualizada = res.body.items.find((a: { id: string }) => a.id === aula.id);
      expect(aulaAtualizada.totalAlunos).toBe(1);
      expect(aulaAtualizada.alunosNomes).toEqual(['Aluno Ativo']);
    });
  });

  describe('Soft delete (correção de cadastro)', () => {
    it('DELETE não remove fisicamente — some da listagem mas continua no banco com deletedAt', async () => {
      const { academia, token, aula } = await cenarioComAula(
        'Academia Soft Delete Aula Calendario E2E',
      );

      await request(app.getHttpServer())
        .delete(`/api/agenda/aulas/${aula.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(204);

      const naListagem = await request(app.getHttpServer())
        .get(`/api/agenda/aulas?turmaId=${aula.turmaId}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(naListagem.body.items.some((a: { id: string }) => a.id === aula.id)).toBe(false);

      const linhaNoBanco = await prisma.aula.findUnique({ where: { id: aula.id } });
      expect(linhaNoBanco).not.toBeNull();
      expect(linhaNoBanco?.deletedAt).not.toBeNull();

      const deleteAudit = await prisma.auditLog.findFirst({
        where: { action: 'AULA_DELETED', academiaId: academia.id },
      });
      expect(deleteAudit).not.toBeNull();
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê, não cancela, não define substituto e não remove aula da academia B', async () => {
      const cenarioA = await cenarioComAula('Academia Isolamento Calendario A E2E');
      const cenarioB = await cenarioComAula('Academia Isolamento Calendario B E2E');

      await request(app.getHttpServer())
        .get(`/api/agenda/aulas/${cenarioB.aula.id}`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(404);

      await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${cenarioB.aula.id}/cancelar`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({})
        .expect(404);

      await request(app.getHttpServer())
        .patch(`/api/agenda/aulas/${cenarioB.aula.id}/substituto`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .send({ professorId: cenarioA.professor.id })
        .expect(404);

      await request(app.getHttpServer())
        .delete(`/api/agenda/aulas/${cenarioB.aula.id}`)
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(404);

      const listaA = await request(app.getHttpServer())
        .get('/api/agenda/aulas')
        .set('Authorization', `Bearer ${cenarioA.token}`)
        .expect(200);
      expect(listaA.body.items.some((a: { id: string }) => a.id === cenarioB.aula.id)).toBe(false);
    });
  });
});
