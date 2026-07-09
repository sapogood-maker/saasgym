import { ConfigService } from '@nestjs/config';
import { ArquivoCategoria } from '@prisma/client';
import { FileUploadService } from './file-upload.service';
import { StorageProvider } from './storage-provider.interface';
import { PrismaService } from '../prisma/prisma.service';

describe('FileUploadService', () => {
  let service: FileUploadService;
  let storageProvider: jest.Mocked<StorageProvider>;
  let prisma: { arquivo: { create: jest.Mock; delete: jest.Mock } };

  beforeEach(() => {
    storageProvider = {
      upload: jest.fn().mockResolvedValue({
        caminho: 'academias/logos/abc.png',
        nomeArmazenado: 'abc.png',
        tamanhoBytes: 123,
        url: '/uploads/academias/logos/abc.png',
      }),
      delete: jest.fn(),
      getSignedUrl: jest.fn().mockResolvedValue('/uploads/academias/logos/abc.png'),
    };
    prisma = {
      arquivo: {
        create: jest.fn().mockResolvedValue({ id: 'arquivo-1' }),
        delete: jest.fn(),
      },
    };
    const configService = { get: () => 'local' } as unknown as ConfigService;

    service = new FileUploadService(
      storageProvider,
      prisma as unknown as PrismaService,
      configService,
    );
  });

  it('uploadAcademiaLogo delega ao StorageProvider e persiste os metadados em Arquivo', async () => {
    const arquivo = await service.uploadAcademiaLogo('academia-1', {
      buffer: Buffer.from('x'),
      originalname: 'logo.png',
      mimetype: 'image/png',
    });

    expect(storageProvider.upload).toHaveBeenCalledWith(
      ArquivoCategoria.ACADEMIA_LOGO,
      Buffer.from('x'),
      { nomeOriginal: 'logo.png', mimeType: 'image/png' },
    );
    expect(prisma.arquivo.create).toHaveBeenCalledWith({
      data: {
        academiaId: 'academia-1',
        categoria: ArquivoCategoria.ACADEMIA_LOGO,
        nomeOriginal: 'logo.png',
        nomeArmazenado: 'abc.png',
        caminho: 'academias/logos/abc.png',
        mimeType: 'image/png',
        tamanhoBytes: 123,
        provider: 'local',
      },
    });
    expect(arquivo).toEqual({ id: 'arquivo-1' });
  });

  it('resolveUrl delega ao StorageProvider', async () => {
    const url = await service.resolveUrl('academias/logos/abc.png');
    expect(storageProvider.getSignedUrl).toHaveBeenCalledWith('academias/logos/abc.png');
    expect(url).toBe('/uploads/academias/logos/abc.png');
  });

  it('delete remove o arquivo do provider e o registro de metadados', async () => {
    const arquivo = {
      id: 'arquivo-1',
      caminho: 'academias/logos/abc.png',
    } as Parameters<FileUploadService['delete']>[0];

    await service.delete(arquivo);

    expect(storageProvider.delete).toHaveBeenCalledWith('academias/logos/abc.png');
    expect(prisma.arquivo.delete).toHaveBeenCalledWith({ where: { id: 'arquivo-1' } });
  });
});
