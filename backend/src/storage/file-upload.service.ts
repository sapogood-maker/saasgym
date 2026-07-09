import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Arquivo, ArquivoCategoria } from '@prisma/client';
import { STORAGE_PROVIDER, StorageProvider } from './storage-provider.interface';
import { PrismaService } from '../prisma/prisma.service';

export interface UploadedFileInput {
  buffer: Buffer;
  originalname: string;
  mimetype: string;
}

/// Camada que o resto do sistema efetivamente usa — combina
/// StorageProvider.upload() com o registro de metadados em Arquivo. Um
/// método por caso de uso (não um upload() genérico): cada categoria pode
/// ganhar validação/lógica própria sem afetar as outras.
@Injectable()
export class FileUploadService {
  constructor(
    @Inject(STORAGE_PROVIDER) private readonly storageProvider: StorageProvider,
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
  ) {}

  async uploadAcademiaLogo(academiaId: string, file: UploadedFileInput): Promise<Arquivo> {
    const result = await this.storageProvider.upload(ArquivoCategoria.ACADEMIA_LOGO, file.buffer, {
      nomeOriginal: file.originalname,
      mimeType: file.mimetype,
    });

    return this.prisma.arquivo.create({
      data: {
        academiaId,
        categoria: ArquivoCategoria.ACADEMIA_LOGO,
        nomeOriginal: file.originalname,
        nomeArmazenado: result.nomeArmazenado,
        caminho: result.caminho,
        mimeType: file.mimetype,
        tamanhoBytes: result.tamanhoBytes,
        provider: this.configService.get<string>('STORAGE_PROVIDER', 'local'),
      },
    });
  }

  resolveUrl(caminho: string): Promise<string> {
    return this.storageProvider.getSignedUrl(caminho);
  }

  /// Remove o arquivo do storage e seu registro de metadados — usado ao
  /// substituir um upload anterior (ex.: trocar o logo), para não acumular
  /// arquivos/linhas órfãs a cada substituição.
  async delete(arquivo: Arquivo): Promise<void> {
    await this.storageProvider.delete(arquivo.caminho);
    await this.prisma.arquivo.delete({ where: { id: arquivo.id } });
  }
}
