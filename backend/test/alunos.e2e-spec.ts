import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import { createAcademiaFixture } from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  'base64',
);

const SENHA = 'SenhaForte123';
const CPF_VALIDO_1 = '111.444.777-35';
const CPF_VALIDO_2 = '529.982.247-25';

describe('Alunos (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string): Promise<string> {
    const email = `${role.toLowerCase()}-alunos-${Date.now()}-${Math.random()}@example.com`;
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
    await request(app.getHttpServer()).get('/api/alunos').expect(401);
  });

  it('SYSTEM_ADMIN (sem academiaId) -> 403 (AcademiaGuard bloqueia)', async () => {
    const senhaHash = await bcrypt.hash(SENHA, 10);
    const email = `sysadmin-alunos-${Date.now()}@example.com`;
    await prisma.user.create({
      data: { nome: 'Sys Admin', email, senhaHash, role: Role.SYSTEM_ADMIN },
    });
    const token = (
      await request(app.getHttpServer()).post('/api/auth/login').send({ email, password: SENHA })
    ).body.accessToken;

    await request(app.getHttpServer())
      .get('/api/alunos')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  describe('CRUD', () => {
    it('ALUNO (sem permissão nenhuma no módulo) -> 403 ao listar', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Aluno Sem Acesso E2E',
      });
      const token = await criarUsuarioELogar(Role.ALUNO, academia.id);

      await request(app.getHttpServer())
        .get('/api/alunos')
        .set('Authorization', `Bearer ${token}`)
        .expect(403);
    });

    it('PROFESSOR consegue listar mas não criar (403)', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Professor Leitura E2E',
      });
      const token = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

      await request(app.getHttpServer())
        .get('/api/alunos')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      await request(app.getHttpServer())
        .post('/api/alunos')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Aluno X',
          cpf: CPF_VALIDO_1,
          dataNascimento: '2000-01-31',
          sexo: 'MASCULINO',
          telefone: '11999999999',
        })
        .expect(403);
    });

    it('ACADEMIA_ADMIN cria, lista, detalha, edita e ativa/inativa um aluno', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia CRUD Aluno E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      const criado = await request(app.getHttpServer())
        .post('/api/alunos')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Fulano de Tal',
          cpf: CPF_VALIDO_1,
          dataNascimento: '2000-01-31',
          sexo: 'MASCULINO',
          telefone: '11999999999',
          email: 'fulano@example.com',
        })
        .expect(201);
      expect(criado.body.status).toBe('ATIVO');
      expect(criado.body.fotoUrl).toBeNull();

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'ALUNO_CREATED', academiaId: academia.id },
      });
      expect(auditEntry).not.toBeNull();

      const detalhe = await request(app.getHttpServer())
        .get(`/api/alunos/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(detalhe.body.nome).toBe('Fulano de Tal');

      const editado = await request(app.getHttpServer())
        .patch(`/api/alunos/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ telefone: '11988887777' })
        .expect(200);
      expect(editado.body.telefone).toBe('11988887777');

      const inativado = await request(app.getHttpServer())
        .patch(`/api/alunos/${criado.body.id}/status`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'INATIVO', motivo: 'Trancou matrícula' })
        .expect(200);
      expect(inativado.body.status).toBe('INATIVO');

      const statusAudit = await prisma.auditLog.findFirst({
        where: { action: 'ALUNO_STATUS_CHANGED', academiaId: academia.id },
      });
      expect(statusAudit?.metadata).toMatchObject({
        statusNovo: 'INATIVO',
        motivo: 'Trancou matrícula',
      });
    });

    it('RECEPCIONISTA também consegue criar e editar', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Recepcionista E2E' });
      const token = await criarUsuarioELogar(Role.RECEPCIONISTA, academia.id);

      await request(app.getHttpServer())
        .post('/api/alunos')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Aluno Recepção',
          cpf: CPF_VALIDO_2,
          dataNascimento: '1995-05-05',
          sexo: 'FEMININO',
          telefone: '11977776666',
        })
        .expect(201);
    });

    it('CPF inválido -> 400', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia CPF Invalido E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .post('/api/alunos')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Aluno CPF Ruim',
          cpf: '111.111.111-11',
          dataNascimento: '2000-01-01',
          sexo: 'OUTRO',
          telefone: '11999999999',
        })
        .expect(400);
    });

    it('CPF duplicado na mesma academia -> 409', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia CPF Duplicado E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);
      const payload = {
        nome: 'Primeiro',
        cpf: CPF_VALIDO_1,
        dataNascimento: '2000-01-01',
        sexo: 'MASCULINO',
        telefone: '11999999999',
      };

      await request(app.getHttpServer())
        .post('/api/alunos')
        .set('Authorization', `Bearer ${token}`)
        .send(payload)
        .expect(201);

      await request(app.getHttpServer())
        .post('/api/alunos')
        .set('Authorization', `Bearer ${token}`)
        .send({ ...payload, nome: 'Segundo' })
        .expect(409);
    });

    it('CPF é normalizado (sem pontuação) e a unicidade não pode ser burlada trocando a máscara', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia CPF Normalizado E2E',
      });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      const criado = await request(app.getHttpServer())
        .post('/api/alunos')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Aluno CPF Mascarado',
          cpf: CPF_VALIDO_1, // '111.444.777-35'
          dataNascimento: '2000-01-01',
          sexo: 'MASCULINO',
          telefone: '11999999999',
        })
        .expect(201);
      expect(criado.body.cpf).toBe('11144477735');

      await request(app.getHttpServer())
        .post('/api/alunos')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Outro Aluno',
          cpf: '11144477735', // mesmo CPF, sem máscara
          dataNascimento: '2000-01-01',
          sexo: 'MASCULINO',
          telefone: '11999999999',
        })
        .expect(409);
    });

    it('mesmo CPF em academias diferentes é permitido', async () => {
      const academiaA = await createAcademiaFixture(prisma, {
        nome: 'Academia CPF Repetido A E2E',
      });
      const academiaB = await createAcademiaFixture(prisma, {
        nome: 'Academia CPF Repetido B E2E',
      });
      const tokenA = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaA.id);
      const tokenB = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaB.id);
      const payload = {
        nome: 'Pessoa',
        cpf: CPF_VALIDO_1,
        dataNascimento: '2000-01-01',
        sexo: 'MASCULINO',
        telefone: '11999999999',
      };

      await request(app.getHttpServer())
        .post('/api/alunos')
        .set('Authorization', `Bearer ${tokenA}`)
        .send(payload)
        .expect(201);

      await request(app.getHttpServer())
        .post('/api/alunos')
        .set('Authorization', `Bearer ${tokenB}`)
        .send(payload)
        .expect(201);
    });

    it('id inexistente -> 404', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia 404 Aluno E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .get('/api/alunos/00000000-0000-0000-0000-000000000099')
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });
  });

  describe('Isolamento entre tenants', () => {
    it('academia A não vê, não edita e não deleta aluno da academia B', async () => {
      const academiaA = await createAcademiaFixture(prisma, {
        nome: 'Academia Isolamento A Aluno E2E',
      });
      const academiaB = await createAcademiaFixture(prisma, {
        nome: 'Academia Isolamento B Aluno E2E',
      });
      const tokenA = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaA.id);
      const tokenB = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaB.id);

      const alunoB = await request(app.getHttpServer())
        .post('/api/alunos')
        .set('Authorization', `Bearer ${tokenB}`)
        .send({
          nome: 'Aluno da B',
          cpf: CPF_VALIDO_1,
          dataNascimento: '2000-01-01',
          sexo: 'MASCULINO',
          telefone: '11999999999',
        })
        .expect(201);

      await request(app.getHttpServer())
        .get(`/api/alunos/${alunoB.body.id}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(404);

      await request(app.getHttpServer())
        .patch(`/api/alunos/${alunoB.body.id}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ nome: 'Hackeado' })
        .expect(404);

      await request(app.getHttpServer())
        .delete(`/api/alunos/${alunoB.body.id}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(404);

      const listaA = await request(app.getHttpServer())
        .get('/api/alunos')
        .set('Authorization', `Bearer ${tokenA}`)
        .expect(200);
      expect(listaA.body.items.some((a: { id: string }) => a.id === alunoB.body.id)).toBe(false);
    });
  });

  describe('Pesquisa e paginação', () => {
    it('pesquisa por nome, CPF e telefone', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Pesquisa E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      await request(app.getHttpServer())
        .post('/api/alunos')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Zezinho da Silva Pesquisável',
          cpf: CPF_VALIDO_1,
          dataNascimento: '2000-01-01',
          sexo: 'MASCULINO',
          telefone: '11955554444',
        })
        .expect(201);

      const porNome = await request(app.getHttpServer())
        .get('/api/alunos?search=Pesquisável')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(porNome.body.total).toBeGreaterThanOrEqual(1);

      const porTelefone = await request(app.getHttpServer())
        .get('/api/alunos?search=55554444')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(porTelefone.body.items.some((a: { nome: string }) => a.nome.includes('Zezinho'))).toBe(
        true,
      );

      // CPF cadastrado com máscara ('111.444.777-35') — a pesquisa precisa
      // achar tanto digitando só números quanto digitando com a máscara.
      const porCpfSemMascara = await request(app.getHttpServer())
        .get('/api/alunos?search=11144477735')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(
        porCpfSemMascara.body.items.some((a: { nome: string }) => a.nome.includes('Zezinho')),
      ).toBe(true);

      const porCpfComMascara = await request(app.getHttpServer())
        .get(`/api/alunos?search=${encodeURIComponent(CPF_VALIDO_1)}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(
        porCpfComMascara.body.items.some((a: { nome: string }) => a.nome.includes('Zezinho')),
      ).toBe(true);

      const semResultado = await request(app.getHttpServer())
        .get('/api/alunos?search=NomeQueNaoExisteInventadoXYZ')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(semResultado.body.total).toBe(0);
    });

    it('pagina corretamente (pageSize pequeno)', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Paginacao E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      for (const cpf of [CPF_VALIDO_1, CPF_VALIDO_2]) {
        await request(app.getHttpServer())
          .post('/api/alunos')
          .set('Authorization', `Bearer ${token}`)
          .send({
            nome: `Aluno Paginado ${cpf}`,
            cpf,
            dataNascimento: '2000-01-01',
            sexo: 'OUTRO',
            telefone: '11999999999',
          })
          .expect(201);
      }

      const pagina1 = await request(app.getHttpServer())
        .get('/api/alunos?pageSize=1&page=1')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(pagina1.body.items).toHaveLength(1);
      expect(pagina1.body.total).toBeGreaterThanOrEqual(2);

      const pagina2 = await request(app.getHttpServer())
        .get('/api/alunos?pageSize=1&page=2')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(pagina2.body.items).toHaveLength(1);
      expect(pagina2.body.items[0].id).not.toBe(pagina1.body.items[0].id);
    });
  });

  describe('Soft delete', () => {
    it('DELETE não remove fisicamente — some da listagem mas continua no banco com deletedAt', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Soft Delete E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      const criado = await request(app.getHttpServer())
        .post('/api/alunos')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Aluno Será Removido',
          cpf: CPF_VALIDO_1,
          dataNascimento: '2000-01-01',
          sexo: 'MASCULINO',
          telefone: '11999999999',
        })
        .expect(201);

      await request(app.getHttpServer())
        .delete(`/api/alunos/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(204);

      await request(app.getHttpServer())
        .get(`/api/alunos/${criado.body.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(404);

      const linhaNoBanco = await prisma.aluno.findUnique({ where: { id: criado.body.id } });
      expect(linhaNoBanco).not.toBeNull();
      expect(linhaNoBanco?.deletedAt).not.toBeNull();

      const deleteAudit = await prisma.auditLog.findFirst({
        where: { action: 'ALUNO_DELETED', academiaId: academia.id },
      });
      expect(deleteAudit).not.toBeNull();
    });
  });

  describe('Upload de foto', () => {
    it('faz upload, serve o arquivo real, e substituir remove o antigo', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Foto Aluno E2E' });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      const criado = await request(app.getHttpServer())
        .post('/api/alunos')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Aluno Com Foto',
          cpf: CPF_VALIDO_1,
          dataNascimento: '2000-01-01',
          sexo: 'MASCULINO',
          telefone: '11999999999',
        })
        .expect(201);

      const primeira = await request(app.getHttpServer())
        .post(`/api/alunos/${criado.body.id}/foto`)
        .set('Authorization', `Bearer ${token}`)
        .attach('file', PNG_1X1, 'foto.png')
        .expect(201);
      expect(primeira.body.fotoUrl).toMatch(/^\/uploads\/alunos\/fotos\/.+\.png$/);

      const arquivoRes = await request(app.getHttpServer()).get(primeira.body.fotoUrl).expect(200);
      expect(Buffer.compare(arquivoRes.body, PNG_1X1)).toBe(0);

      const segunda = await request(app.getHttpServer())
        .post(`/api/alunos/${criado.body.id}/foto`)
        .set('Authorization', `Bearer ${token}`)
        .attach('file', PNG_1X1, 'foto2.png')
        .expect(201);
      expect(segunda.body.fotoUrl).not.toBe(primeira.body.fotoUrl);

      await request(app.getHttpServer()).get(primeira.body.fotoUrl).expect(404);
    });

    it('rejeita formato não suportado -> 400', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Foto Formato Aluno E2E',
      });
      const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

      const criado = await request(app.getHttpServer())
        .post('/api/alunos')
        .set('Authorization', `Bearer ${token}`)
        .send({
          nome: 'Aluno Foto Ruim',
          cpf: CPF_VALIDO_1,
          dataNascimento: '2000-01-01',
          sexo: 'MASCULINO',
          telefone: '11999999999',
        })
        .expect(201);

      await request(app.getHttpServer())
        .post(`/api/alunos/${criado.body.id}/foto`)
        .set('Authorization', `Bearer ${token}`)
        .attach('file', Buffer.from('não é imagem'), 'arquivo.txt')
        .expect(400);
    });
  });
});
