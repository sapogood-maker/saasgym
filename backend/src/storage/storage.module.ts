import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FileUploadService } from './file-upload.service';
import { LocalDiskStorageProvider } from './local-disk-storage.provider';
import { STORAGE_PROVIDER, StorageProvider } from './storage-provider.interface';

/// Único módulo que sabe qual implementação concreta de StorageProvider
/// está em uso (via STORAGE_PROVIDER no ambiente) — todo o resto do sistema
/// importa só FileUploadService. Selecionar um provider ainda não
/// implementado falha alto e claro no boot, não silenciosamente.
@Module({
  providers: [
    {
      provide: STORAGE_PROVIDER,
      useFactory: (configService: ConfigService): StorageProvider => {
        const provider = configService.get<string>('STORAGE_PROVIDER', 'local');
        if (provider === 'local') {
          return new LocalDiskStorageProvider(configService);
        }
        throw new Error(
          `StorageProvider "${provider}" ainda não tem implementação — só "local" existe nesta sprint.`,
        );
      },
      inject: [ConfigService],
    },
    FileUploadService,
  ],
  exports: [FileUploadService],
})
export class StorageModule {}
