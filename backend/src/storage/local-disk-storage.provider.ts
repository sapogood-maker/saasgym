import { randomUUID } from 'node:crypto';
import { mkdir, unlink, writeFile } from 'node:fs/promises';
import { extname, join, posix } from 'node:path';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ArquivoCategoria } from '@prisma/client';
import { StorageProvider, UploadOptions, UploadResult } from './storage-provider.interface';

/// Cada categoria mora numa pasta fixa, compartilhada entre todas as
/// academias (o isolamento por tenant vem do registro em Arquivo.academiaId,
/// não da estrutura de pastas). Novas categorias entram aqui junto com o
/// enum ArquivoCategoria quando o módulo correspondente existir.
const CATEGORIA_PASTA: Record<ArquivoCategoria, string> = {
  [ArquivoCategoria.ACADEMIA_LOGO]: 'academias/logos',
  [ArquivoCategoria.ALUNO_FOTO]: 'alunos/fotos',
  [ArquivoCategoria.PROFESSOR_FOTO]: 'professores/fotos',
  [ArquivoCategoria.USER_AVATAR]: 'usuarios/avatares',
};

/// Implementação de referência do StorageProvider — grava em disco, num
/// diretório persistente (volume Docker em produção). Caminhos lógicos
/// (armazenados em Arquivo.caminho e usados em URLs) usam sempre "/" via
/// node:path/posix, independente do SO onde o processo roda; só a escrita
/// em disco de fato usa o separador nativo do SO.
@Injectable()
export class LocalDiskStorageProvider implements StorageProvider {
  private readonly uploadsDir: string;

  constructor(private readonly configService: ConfigService) {
    this.uploadsDir = this.configService.get<string>('UPLOADS_DIR', './uploads');
  }

  async upload(
    categoria: ArquivoCategoria,
    buffer: Buffer,
    options: UploadOptions,
  ): Promise<UploadResult> {
    const pasta = CATEGORIA_PASTA[categoria];
    const nomeArmazenado = `${randomUUID()}${extname(options.nomeOriginal)}`;
    const caminho = posix.join(pasta, nomeArmazenado);

    await mkdir(join(this.uploadsDir, pasta), { recursive: true });
    await writeFile(join(this.uploadsDir, ...caminho.split('/')), buffer);

    return {
      caminho,
      nomeArmazenado,
      tamanhoBytes: buffer.length,
      url: await this.getSignedUrl(caminho),
    };
  }

  async delete(caminho: string): Promise<void> {
    await unlink(join(this.uploadsDir, ...caminho.split('/'))).catch(() => undefined);
  }

  getSignedUrl(caminho: string): Promise<string> {
    // PUBLIC_API_PREFIX: mesma razão do Path do cookie de refresh em
    // AuthController — atrás de um proxy que publica a API sob um path
    // externo, a URL de upload precisa incluir esse prefixo para o navegador
    // conseguir buscar o arquivo de volta.
    const publicApiPrefix = this.configService.get<string>('PUBLIC_API_PREFIX', '');
    return Promise.resolve(`${publicApiPrefix}/uploads/${caminho}`);
  }
}
