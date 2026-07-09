import { INestApplication } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { createTestApp } from './utils/create-test-app';
import { createAcademiaFixture } from './utils/fixtures';
import { PrismaService } from '../src/prisma/prisma.service';

// PNG 1x1 transparente válido — pequeno o bastante para inline, real o
// bastante para o FileInterceptor/sharp-like checks não rejeitarem.
const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  'base64',
);

describe('Admin Academias (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let systemAdminToken: string;
  let academiaAdminToken: string;

  async function loginAs(email: string, password: string): Promise<string> {
    const res = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email, password })
      .expect(200);
    return res.body.accessToken;
  }

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);

    const senha = 'SenhaForte123';
    const senhaHash = await bcrypt.hash(senha, 10);

    const sysAdminEmail = `sysadmin-${Date.now()}@example.com`;
    await prisma.user.create({
      data: { nome: 'Sys Admin E2E', email: sysAdminEmail, senhaHash, role: Role.SYSTEM_ADMIN },
    });
    systemAdminToken = await loginAs(sysAdminEmail, senha);

    const academiaComum = await createAcademiaFixture(prisma, { nome: 'Academia Comum E2E' });
    const academiaAdminEmail = `academiaadmin-${Date.now()}@example.com`;
    await prisma.user.create({
      data: {
        nome: 'Academia Admin E2E',
        email: academiaAdminEmail,
        senhaHash,
        role: Role.ACADEMIA_ADMIN,
        academiaId: academiaComum.id,
      },
    });
    academiaAdminToken = await loginAs(academiaAdminEmail, senha);
  });

  afterAll(async () => {
    await app.close();
  });

  describe('POST /api/admin/academias', () => {
    it('sem token -> 401', async () => {
      await request(app.getHttpServer()).post('/api/admin/academias').send({}).expect(401);
    });

    it('com token de ACADEMIA_ADMIN (não é SYSTEM_ADMIN) -> 403', async () => {
      await request(app.getHttpServer())
        .post('/api/admin/academias')
        .set('Authorization', `Bearer ${academiaAdminToken}`)
        .send({ nome: 'X', adminInicial: { nome: 'X', email: 'x@x.com', senha: 'SenhaForte123' } })
        .expect(403);
    });

    it('payload inválido (sem adminInicial) -> 400', async () => {
      await request(app.getHttpServer())
        .post('/api/admin/academias')
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .send({ nome: 'Academia Sem Admin' })
        .expect(400);
    });

    it('cria academia + admin numa transação -> 201, e o admin já consegue logar', async () => {
      const email = `novo-admin-${Date.now()}@example.com`;

      const res = await request(app.getHttpServer())
        .post('/api/admin/academias')
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .send({
          nome: 'Academia Criada via HTTP',
          cnpj: `HTTP-${Date.now()}`,
          adminInicial: { nome: 'Novo Admin', email, senha: 'SenhaForte123' },
        })
        .expect(201);

      expect(res.body.status).toBe('TRIAL');
      expect(res.body.id).toBeDefined();

      await loginAs(email, 'SenhaForte123');

      await prisma.academia.delete({ where: { id: res.body.id } });
    });
  });

  describe('GET /api/admin/academias', () => {
    it('sem token -> 401', async () => {
      await request(app.getHttpServer()).get('/api/admin/academias').expect(401);
    });

    it('lista paginada com token de SYSTEM_ADMIN -> 200', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/admin/academias')
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .expect(200);

      expect(Array.isArray(res.body.items)).toBe(true);
      expect(res.body.total).toBeGreaterThanOrEqual(1);
      expect(res.body.page).toBe(1);
    });

    it('filtra por status', async () => {
      const outraAcademia = await createAcademiaFixture(prisma, {
        nome: 'Academia Bloqueada Filtro E2E',
        status: 'BLOQUEADA',
      });

      const res = await request(app.getHttpServer())
        .get('/api/admin/academias?status=BLOQUEADA')
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .expect(200);

      expect(res.body.items.every((a: { status: string }) => a.status === 'BLOQUEADA')).toBe(true);
      expect(res.body.items.some((a: { id: string }) => a.id === outraAcademia.id)).toBe(true);
    });
  });

  describe('GET /api/admin/academias/:id', () => {
    it('detalhe de uma academia existente', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Detalhe E2E' });

      const res = await request(app.getHttpServer())
        .get(`/api/admin/academias/${academia.id}`)
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .expect(200);

      expect(res.body.id).toBe(academia.id);
      expect(res.body.nome).toBe('Academia Detalhe E2E');
    });

    it('id inexistente (mas válido) -> 404', async () => {
      await request(app.getHttpServer())
        .get('/api/admin/academias/00000000-0000-0000-0000-000000000099')
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .expect(404);
    });

    it('id malformado (não-UUID) -> 400', async () => {
      await request(app.getHttpServer())
        .get('/api/admin/academias/nao-e-um-uuid')
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .expect(400);
    });
  });

  describe('PATCH /api/admin/academias/:id', () => {
    it('edita campos cadastrais e audita ACADEMIA_UPDATED', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Antes Da Edição' });

      const res = await request(app.getHttpServer())
        .patch(`/api/admin/academias/${academia.id}`)
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .send({ nome: 'Academia Depois Da Edição', telefone: '11999999999' })
        .expect(200);

      expect(res.body.nome).toBe('Academia Depois Da Edição');
      expect(res.body.telefone).toBe('11999999999');

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'ACADEMIA_UPDATED', academiaId: academia.id },
      });
      expect(auditEntry).not.toBeNull();
    });

    it('id inexistente -> 404', async () => {
      await request(app.getHttpServer())
        .patch('/api/admin/academias/00000000-0000-0000-0000-000000000099')
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .send({ nome: 'Não Importa' })
        .expect(404);
    });
  });

  describe('PATCH /api/admin/academias/:id/status', () => {
    it('sem token de SYSTEM_ADMIN -> 403', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Status 403 E2E' });

      await request(app.getHttpServer())
        .patch(`/api/admin/academias/${academia.id}/status`)
        .set('Authorization', `Bearer ${academiaAdminToken}`)
        .send({ status: 'BLOQUEADA' })
        .expect(403);
    });

    it('transicionar para SUSPENSA revoga em cascata as sessões ativas dos usuários da academia', async () => {
      const senha = 'SenhaForte123';
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Suspensão E2E' });
      const email = `usuario-suspenso-${Date.now()}@example.com`;
      await prisma.user.create({
        data: {
          nome: 'Usuário Será Suspenso',
          email,
          senhaHash: await bcrypt.hash(senha, 10),
          role: Role.ACADEMIA_ADMIN,
          academiaId: academia.id,
        },
      });

      const loginRes = await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email, password: senha })
        .expect(200);
      const refreshCookie = (loginRes.headers['set-cookie'] as unknown as string[])
        .find((c) => c.startsWith('refreshToken='))!
        .split(';')[0];

      // sessão ativa no momento da suspensão — é exatamente esta que a
      // cascata precisa revogar. (Login *depois* da suspensão ainda não é
      // bloqueado — essa checagem é a Etapa 6, não esta.)
      const statusRes = await request(app.getHttpServer())
        .patch(`/api/admin/academias/${academia.id}/status`)
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .send({ status: 'SUSPENSA', motivo: 'Pendência de pagamento (teste e2e)' })
        .expect(200);
      expect(statusRes.body.status).toBe('SUSPENSA');

      // a sessão que estava ativa quando a academia foi suspensa não
      // funciona mais.
      await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .set('Cookie', refreshCookie)
        .expect(401);

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'ACADEMIA_STATUS_CHANGED', academiaId: academia.id },
        orderBy: { createdAt: 'desc' },
      });
      expect(auditEntry?.metadata).toMatchObject({
        statusAnterior: 'TRIAL',
        statusNovo: 'SUSPENSA',
        motivo: 'Pendência de pagamento (teste e2e)',
      });
    });

    it('transicionar para ATIVA não revoga sessões de outras academias (isolamento)', async () => {
      const senha = 'SenhaForte123';
      const academiaAlvo = await createAcademiaFixture(prisma, {
        nome: 'Academia Alvo Status E2E',
      });
      const academiaOutra = await createAcademiaFixture(prisma, {
        nome: 'Academia Outra Status E2E',
      });
      const emailOutra = `usuario-outra-${Date.now()}@example.com`;
      await prisma.user.create({
        data: {
          nome: 'Usuário Outra Academia',
          email: emailOutra,
          senhaHash: await bcrypt.hash(senha, 10),
          role: Role.ACADEMIA_ADMIN,
          academiaId: academiaOutra.id,
        },
      });

      await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: emailOutra, password: senha })
        .expect(200);

      await request(app.getHttpServer())
        .patch(`/api/admin/academias/${academiaAlvo.id}/status`)
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .send({ status: 'ATIVA' })
        .expect(200);

      const tokensOutra = await prisma.refreshToken.findMany({
        where: { user: { academiaId: academiaOutra.id } },
      });
      expect(tokensOutra.every((t) => t.revokedAt === null)).toBe(true);
    });
  });

  describe('GET/PUT /api/admin/academias/:id/configuracao', () => {
    // createAcademiaFixture cria só o registro de Academia (não passa pelo
    // fluxo real de provisionamento) — nos testes que esperam a
    // configuração já existir, criamos a linha explicitamente aqui,
    // simulando o que AcademiaProvisioningService faz de verdade.
    it('academia provisionada de verdade já nasce com configuração vazia', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Config Vazia E2E' });
      await prisma.academiaConfiguracao.create({ data: { academiaId: academia.id } });

      const res = await request(app.getHttpServer())
        .get(`/api/admin/academias/${academia.id}/configuracao`)
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .expect(200);

      expect(res.body.academiaId).toBe(academia.id);
      expect(res.body.logoUrl).toBeNull();
      expect(res.body.whatsapp).toBeNull();
    });

    it('sem token de SYSTEM_ADMIN -> 403', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Config 403 E2E' });
      await prisma.academiaConfiguracao.create({ data: { academiaId: academia.id } });

      await request(app.getHttpServer())
        .get(`/api/admin/academias/${academia.id}/configuracao`)
        .set('Authorization', `Bearer ${academiaAdminToken}`)
        .expect(403);
    });

    it('academia sem linha de configuração -> 404', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Sem Config E2E' });

      await request(app.getHttpServer())
        .get(`/api/admin/academias/${academia.id}/configuracao`)
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .expect(404);
    });

    it('PUT atualiza o branding e audita ACADEMIA_CONFIGURACAO_UPDATED', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Config Update E2E' });
      await prisma.academiaConfiguracao.create({ data: { academiaId: academia.id } });

      const res = await request(app.getHttpServer())
        .put(`/api/admin/academias/${academia.id}/configuracao`)
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .send({
          whatsapp: '11988887777',
          instagram: '@academiateste',
          temaCores: { primaria: '#0055FF' },
          horarioFuncionamento: { seg: '06:00-22:00' },
        })
        .expect(200);

      expect(res.body.whatsapp).toBe('11988887777');
      expect(res.body.instagram).toBe('@academiateste');
      expect(res.body.temaCores).toEqual({ primaria: '#0055FF' });
      expect(res.body.horarioFuncionamento).toEqual({ seg: '06:00-22:00' });

      const auditEntry = await prisma.auditLog.findFirst({
        where: { action: 'ACADEMIA_CONFIGURACAO_UPDATED', academiaId: academia.id },
      });
      expect(auditEntry).not.toBeNull();

      const relido = await request(app.getHttpServer())
        .get(`/api/admin/academias/${academia.id}/configuracao`)
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .expect(200);
      expect(relido.body.whatsapp).toBe('11988887777');
    });
  });

  describe('POST /api/admin/academias/:id/logo', () => {
    it('faz upload, retorna a URL pública, e o arquivo responde de verdade em /uploads/...', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Logo Upload E2E' });
      await prisma.academiaConfiguracao.create({ data: { academiaId: academia.id } });

      const res = await request(app.getHttpServer())
        .post(`/api/admin/academias/${academia.id}/logo`)
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .attach('file', PNG_1X1, 'logo.png')
        .expect(201);

      expect(res.body.logoUrl).toMatch(/^\/uploads\/academias\/logos\/.+\.png$/);

      const arquivoRes = await request(app.getHttpServer()).get(res.body.logoUrl).expect(200);
      expect(Buffer.compare(arquivoRes.body, PNG_1X1)).toBe(0);

      const arquivo = await prisma.arquivo.findFirst({ where: { academiaId: academia.id } });
      expect(arquivo?.nomeOriginal).toBe('logo.png');
      expect(arquivo?.nomeArmazenado).not.toBe('logo.png');
    });

    it('rejeita formato não suportado (ex.: text/plain) -> 400', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Logo Formato E2E' });
      await prisma.academiaConfiguracao.create({ data: { academiaId: academia.id } });

      await request(app.getHttpServer())
        .post(`/api/admin/academias/${academia.id}/logo`)
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .attach('file', Buffer.from('não é uma imagem'), 'arquivo.txt')
        .expect(400);
    });

    it('sem nenhum arquivo anexado -> 400', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Logo Sem Arquivo E2E',
      });
      await prisma.academiaConfiguracao.create({ data: { academiaId: academia.id } });

      await request(app.getHttpServer())
        .post(`/api/admin/academias/${academia.id}/logo`)
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .expect(400);
    });

    it('substituir o logo remove o arquivo/registro antigo (sem acumular órfãos)', async () => {
      const academia = await createAcademiaFixture(prisma, {
        nome: 'Academia Logo Substituição E2E',
      });
      await prisma.academiaConfiguracao.create({ data: { academiaId: academia.id } });

      const primeiro = await request(app.getHttpServer())
        .post(`/api/admin/academias/${academia.id}/logo`)
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .attach('file', PNG_1X1, 'logo1.png')
        .expect(201);

      const segundo = await request(app.getHttpServer())
        .post(`/api/admin/academias/${academia.id}/logo`)
        .set('Authorization', `Bearer ${systemAdminToken}`)
        .attach('file', PNG_1X1, 'logo2.png')
        .expect(201);

      expect(segundo.body.logoUrl).not.toBe(primeiro.body.logoUrl);

      // o arquivo antigo não responde mais (foi apagado do disco)
      await request(app.getHttpServer()).get(primeiro.body.logoUrl).expect(404);
      await request(app.getHttpServer()).get(segundo.body.logoUrl).expect(200);

      const arquivos = await prisma.arquivo.findMany({ where: { academiaId: academia.id } });
      expect(arquivos).toHaveLength(1);
    });

    it('sem token de SYSTEM_ADMIN -> 403', async () => {
      const academia = await createAcademiaFixture(prisma, { nome: 'Academia Logo 403 E2E' });

      await request(app.getHttpServer())
        .post(`/api/admin/academias/${academia.id}/logo`)
        .set('Authorization', `Bearer ${academiaAdminToken}`)
        .attach('file', PNG_1X1, 'logo.png')
        .expect(403);
    });
  });
});
