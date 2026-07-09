import { Module } from '@nestjs/common';
import { AlunosController } from './alunos.controller';
import { AlunosService } from './alunos.service';
import { AuditModule } from '../audit/audit.module';
import { StorageModule } from '../../storage/storage.module';

@Module({
  imports: [AuditModule, StorageModule],
  controllers: [AlunosController],
  providers: [AlunosService],
})
export class AlunosModule {}
