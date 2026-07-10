import { ConfigService } from '@nestjs/config';
import { ArquivoCategoria } from '@prisma/client';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { LocalDiskStorageProvider } from './local-disk-storage.provider';

describe('LocalDiskStorageProvider', () => {
  let uploadsDir: string;
  let provider: LocalDiskStorageProvider;
  let publicApiPrefix: string;

  beforeEach(async () => {
    uploadsDir = await mkdtemp(join(tmpdir(), 'saasgym-storage-'));
    publicApiPrefix = '';
    const configService = {
      get: (key: string, defaultValue?: unknown) =>
        key === 'UPLOADS_DIR' ? uploadsDir : (publicApiPrefix ?? defaultValue),
    } as unknown as ConfigService;
    provider = new LocalDiskStorageProvider(configService);
  });

  afterEach(async () => {
    await rm(uploadsDir, { recursive: true, force: true });
  });

  it('grava o arquivo em disco com nome físico em UUID, nunca o nome original', async () => {
    const result = await provider.upload(ArquivoCategoria.ACADEMIA_LOGO, Buffer.from('conteudo'), {
      nomeOriginal: 'logo bonito.png',
      mimeType: 'image/png',
    });

    expect(result.nomeArmazenado).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.png$/,
    );
    expect(result.nomeArmazenado).not.toContain('logo bonito');
    expect(result.caminho).toBe(`academias/logos/${result.nomeArmazenado}`);
    expect(result.tamanhoBytes).toBe(Buffer.from('conteudo').length);

    const gravado = await readFile(join(uploadsDir, 'academias', 'logos', result.nomeArmazenado));
    expect(gravado.toString()).toBe('conteudo');
  });

  it('organiza por categoria (pasta fixa por ArquivoCategoria)', async () => {
    const result = await provider.upload(ArquivoCategoria.ACADEMIA_LOGO, Buffer.from('x'), {
      nomeOriginal: 'a.png',
      mimeType: 'image/png',
    });

    expect(result.caminho.startsWith('academias/logos/')).toBe(true);
  });

  it('cada upload gera um nome físico diferente, mesmo com o mesmo nome original', async () => {
    const a = await provider.upload(ArquivoCategoria.ACADEMIA_LOGO, Buffer.from('a'), {
      nomeOriginal: 'igual.png',
      mimeType: 'image/png',
    });
    const b = await provider.upload(ArquivoCategoria.ACADEMIA_LOGO, Buffer.from('b'), {
      nomeOriginal: 'igual.png',
      mimeType: 'image/png',
    });

    expect(a.nomeArmazenado).not.toBe(b.nomeArmazenado);
  });

  it('getSignedUrl resolve a URL pública estática (sem assinatura real no provider local)', async () => {
    const url = await provider.getSignedUrl('academias/logos/algum-arquivo.png');
    expect(url).toBe('/uploads/academias/logos/algum-arquivo.png');
  });

  it('getSignedUrl inclui PUBLIC_API_PREFIX quando configurado (deploy atrás de path externo)', async () => {
    publicApiPrefix = '/saasgym-api';
    const url = await provider.getSignedUrl('academias/logos/algum-arquivo.png');
    expect(url).toBe('/saasgym-api/uploads/academias/logos/algum-arquivo.png');
  });

  it('delete remove o arquivo do disco', async () => {
    const result = await provider.upload(ArquivoCategoria.ACADEMIA_LOGO, Buffer.from('x'), {
      nomeOriginal: 'a.png',
      mimeType: 'image/png',
    });
    const caminhoFisico = join(uploadsDir, 'academias', 'logos', result.nomeArmazenado);

    await expect(readFile(caminhoFisico)).resolves.toBeDefined();
    await provider.delete(result.caminho);
    await expect(readFile(caminhoFisico)).rejects.toThrow();
  });

  it('delete de um arquivo inexistente não lança (idempotente)', async () => {
    await expect(provider.delete('academias/logos/nao-existe.png')).resolves.toBeUndefined();
  });
});
