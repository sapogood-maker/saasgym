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

describe('Professores (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  async function criarUsuarioELogar(role: Role, academiaId: string): Promise<string> {
    const email = `${role.toLowerCase()}-professores-${Date.now()}-${Math.random()}@example.com`;
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
    await request(app.getHttpServer()).get('/api/professores').expect(401);
  });

  it('PROFESSOR consegue listar mas não criar (403)', async () => {
    const academia = await createAcademiaFixture(prisma, {
      nome: 'Academia Professor Leitura Prof E2E',
    });
    const token = await criarUsuarioELogar(Role.PROFESSOR, academia.id);

    await request(app.getHttpServer())
      .get('/api/professores')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    await request(app.getHttpServer())
      .post('/api/professores')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Professor X', cpf: CPF_VALIDO_1, telefone: '11999999999' })
      .expect(403);
  });

  it('ACADEMIA_ADMIN cria, lista, detalha, edita e ativa/inativa um professor', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia CRUD Professor E2E' });
    const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

    const criado = await request(app.getHttpServer())
      .post('/api/professores')
      .set('Authorization', `Bearer ${token}`)
      .send({
        nome: 'Professor Fulano',
        cpf: CPF_VALIDO_1,
        telefone: '11999999999',
        especialidade: 'Musculação',
      })
      .expect(201);
    expect(criado.body.status).toBe('ATIVO');

    const auditEntry = await prisma.auditLog.findFirst({
      where: { action: 'PROFESSOR_CREATED', academiaId: academia.id },
    });
    expect(auditEntry).not.toBeNull();
    expect(auditEntry?.ipAddress).toBeTruthy();

    const detalhe = await request(app.getHttpServer())
      .get(`/api/professores/${criado.body.id}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(detalhe.body.especialidade).toBe('Musculação');

    const editado = await request(app.getHttpServer())
      .patch(`/api/professores/${criado.body.id}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ especialidade: 'Crossfit' })
      .expect(200);
    expect(editado.body.especialidade).toBe('Crossfit');

    const inativado = await request(app.getHttpServer())
      .patch(`/api/professores/${criado.body.id}/status`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'INATIVO' })
      .expect(200);
    expect(inativado.body.status).toBe('INATIVO');
  });

  it('CPF duplicado na mesma academia -> 409, mas permitido em academias diferentes', async () => {
    const academiaA = await createAcademiaFixture(prisma, { nome: 'Academia CPF Prof A E2E' });
    const academiaB = await createAcademiaFixture(prisma, { nome: 'Academia CPF Prof B E2E' });
    const tokenA = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaA.id);
    const tokenB = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaB.id);
    const payload = { nome: 'Professor', cpf: CPF_VALIDO_1, telefone: '11999999999' };

    await request(app.getHttpServer())
      .post('/api/professores')
      .set('Authorization', `Bearer ${tokenA}`)
      .send(payload)
      .expect(201);

    await request(app.getHttpServer())
      .post('/api/professores')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ ...payload, nome: 'Outro' })
      .expect(409);

    await request(app.getHttpServer())
      .post('/api/professores')
      .set('Authorization', `Bearer ${tokenB}`)
      .send(payload)
      .expect(201);
  });

  it('CPF é normalizado (sem pontuação) e a unicidade não pode ser burlada trocando a máscara', async () => {
    const academia = await createAcademiaFixture(prisma, {
      nome: 'Academia CPF Normalizado Prof E2E',
    });
    const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

    const criado = await request(app.getHttpServer())
      .post('/api/professores')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Professor CPF Mascarado', cpf: CPF_VALIDO_1, telefone: '11999999999' })
      .expect(201);
    expect(criado.body.cpf).toBe('11144477735');

    await request(app.getHttpServer())
      .post('/api/professores')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Outro Professor', cpf: '11144477735', telefone: '11999999999' })
      .expect(409);
  });

  it('isolamento entre tenants: academia A não vê/edita/deleta professor da academia B', async () => {
    const academiaA = await createAcademiaFixture(prisma, {
      nome: 'Academia Isolamento A Prof E2E',
    });
    const academiaB = await createAcademiaFixture(prisma, {
      nome: 'Academia Isolamento B Prof E2E',
    });
    const tokenA = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaA.id);
    const tokenB = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academiaB.id);

    const professorB = await request(app.getHttpServer())
      .post('/api/professores')
      .set('Authorization', `Bearer ${tokenB}`)
      .send({ nome: 'Professor da B', cpf: CPF_VALIDO_1, telefone: '11999999999' })
      .expect(201);

    await request(app.getHttpServer())
      .get(`/api/professores/${professorB.body.id}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(404);

    await request(app.getHttpServer())
      .delete(`/api/professores/${professorB.body.id}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(404);
  });

  it('pesquisa e paginação', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Pesquisa Prof E2E' });
    const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

    await request(app.getHttpServer())
      .post('/api/professores')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Professor Pesquisável Especial', cpf: CPF_VALIDO_1, telefone: '11955554444' })
      .expect(201);
    await request(app.getHttpServer())
      .post('/api/professores')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Outro Professor', cpf: CPF_VALIDO_2, telefone: '11933332222' })
      .expect(201);

    const porNome = await request(app.getHttpServer())
      .get('/api/professores?search=Pesquisável')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(porNome.body.total).toBe(1);

    // CPF cadastrado com máscara ('111.444.777-35') — a pesquisa precisa
    // achar tanto digitando só números quanto digitando com a máscara.
    const porCpfSemMascara = await request(app.getHttpServer())
      .get('/api/professores?search=11144477735')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(porCpfSemMascara.body.total).toBe(1);

    const porCpfComMascara = await request(app.getHttpServer())
      .get(`/api/professores?search=${encodeURIComponent(CPF_VALIDO_1)}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(porCpfComMascara.body.total).toBe(1);

    const pagina1 = await request(app.getHttpServer())
      .get('/api/professores?pageSize=1&page=1')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(pagina1.body.items).toHaveLength(1);
    expect(pagina1.body.total).toBeGreaterThanOrEqual(2);
  });

  it('soft delete: some da listagem, permanece no banco com deletedAt', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Soft Delete Prof E2E' });
    const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

    const criado = await request(app.getHttpServer())
      .post('/api/professores')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Professor Será Removido', cpf: CPF_VALIDO_1, telefone: '11999999999' })
      .expect(201);

    await request(app.getHttpServer())
      .delete(`/api/professores/${criado.body.id}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(204);

    await request(app.getHttpServer())
      .get(`/api/professores/${criado.body.id}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(404);

    const linha = await prisma.professor.findUnique({ where: { id: criado.body.id } });
    expect(linha).not.toBeNull();
    expect(linha?.deletedAt).not.toBeNull();
  });

  it('upload de foto: substituir remove o arquivo antigo', async () => {
    const academia = await createAcademiaFixture(prisma, { nome: 'Academia Foto Prof E2E' });
    const token = await criarUsuarioELogar(Role.ACADEMIA_ADMIN, academia.id);

    const criado = await request(app.getHttpServer())
      .post('/api/professores')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Professor Com Foto', cpf: CPF_VALIDO_1, telefone: '11999999999' })
      .expect(201);

    const primeira = await request(app.getHttpServer())
      .post(`/api/professores/${criado.body.id}/foto`)
      .set('Authorization', `Bearer ${token}`)
      .attach('file', PNG_1X1, 'foto.png')
      .expect(201);
    expect(primeira.body.fotoUrl).toMatch(/^\/uploads\/professores\/fotos\/.+\.png$/);

    const arquivoRes = await request(app.getHttpServer()).get(primeira.body.fotoUrl).expect(200);
    expect(Buffer.compare(arquivoRes.body, PNG_1X1)).toBe(0);

    const segunda = await request(app.getHttpServer())
      .post(`/api/professores/${criado.body.id}/foto`)
      .set('Authorization', `Bearer ${token}`)
      .attach('file', PNG_1X1, 'foto2.png')
      .expect(201);

    await request(app.getHttpServer()).get(primeira.body.fotoUrl).expect(404);
    await request(app.getHttpServer()).get(segunda.body.fotoUrl).expect(200);
  });
});
