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
/// método público por caso de uso (não um upload() genérico exposto): cada
/// categoria pode ganhar validação/lógica própria sem afetar as outras.
/// Todos compartilham o mesmo helper privado — a única coisa que muda de
/// um caso para outro é a categoria e a quem o arquivo pertence.
@Injectable()
export class FileUploadService {
  constructor(
    @Inject(STORAGE_PROVIDER) private readonly storageProvider: StorageProvider,
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
  ) {}

  uploadAcademiaLogo(academiaId: string, file: UploadedFileInput): Promise<Arquivo> {
    return this.uploadFoto(ArquivoCategoria.ACADEMIA_LOGO, academiaId, file);
  }

  uploadAlunoFoto(academiaId: string, file: UploadedFileInput): Promise<Arquivo> {
    return this.uploadFoto(ArquivoCategoria.ALUNO_FOTO, academiaId, file);
  }

  uploadProfessorFoto(academiaId: string, file: UploadedFileInput): Promise<Arquivo> {
    return this.uploadFoto(ArquivoCategoria.PROFESSOR_FOTO, academiaId, file);
  }

  /// academiaId nulo para SYSTEM_ADMIN (não pertence a nenhuma academia) —
  /// único caso entre os quatro em que isso acontece.
  uploadUserAvatar(academiaId: string | null, file: UploadedFileInput): Promise<Arquivo> {
    return this.uploadFoto(ArquivoCategoria.USER_AVATAR, academiaId, file);
  }

  resolveUrl(caminho: string): Promise<string> {
    return this.storageProvider.getSignedUrl(caminho);
  }

  /// Remove o arquivo do storage e seu registro de metadados — usado ao
  /// substituir um upload anterior (ex.: trocar uma foto), para não
  /// acumular arquivos/linhas órfãs a cada substituição.
  async delete(arquivo: Arquivo): Promise<void> {
    await this.storageProvider.delete(arquivo.caminho);
    await this.prisma.arquivo.delete({ where: { id: arquivo.id } });
  }

  private async uploadFoto(
    categoria: ArquivoCategoria,
    academiaId: string | null,
    file: UploadedFileInput,
  ): Promise<Arquivo> {
    const result = await this.storageProvider.upload(categoria, file.buffer, {
      nomeOriginal: file.originalname,
      mimeType: file.mimetype,
    });

    return this.prisma.arquivo.create({
      data: {
        academiaId,
        categoria,
        nomeOriginal: file.originalname,
        nomeArmazenado: result.nomeArmazenado,
        caminho: result.caminho,
        mimeType: file.mimetype,
        tamanhoBytes: result.tamanhoBytes,
        provider: this.configService.get<string>('STORAGE_PROVIDER', 'local'),
      },
    });
  }
}
