import { ArquivoCategoria } from '@prisma/client';

export interface UploadOptions {
  nomeOriginal: string;
  mimeType: string;
}

export interface UploadResult {
  /// Chave/caminho relativo usado pelo provider para localizar o arquivo
  /// depois (delete, getSignedUrl) — é o que vai para Arquivo.caminho.
  caminho: string;
  /// Nome físico gerado (sempre UUID + extensão, nunca o nome original).
  nomeArmazenado: string;
  tamanhoBytes: number;
  /// URL resolvida logo após o upload — conveniência para o chamador não
  /// precisar de uma segunda chamada a getSignedUrl() no caminho feliz.
  url: string;
}

/// Único ponto de contato que o resto do sistema conhece para armazenar
/// arquivos — nenhum módulo de negócio importa uma implementação concreta
/// diretamente (ver StorageModule). Trocar de local disk para R2/S3/etc.
/// significa escrever uma nova classe aqui, sem tocar em quem chama.
export interface StorageProvider {
  upload(
    categoria: ArquivoCategoria,
    buffer: Buffer,
    options: UploadOptions,
  ): Promise<UploadResult>;
  delete(caminho: string): Promise<void>;
  /// Para o provider local, apenas resolve a URL pública estática (sem
  /// assinatura real). Providers privados (S3/R2) implementam uma URL
  /// assinada e temporária de verdade sem mudar essa assinatura.
  getSignedUrl(caminho: string): Promise<string>;
}

export const STORAGE_PROVIDER = Symbol('STORAGE_PROVIDER');
