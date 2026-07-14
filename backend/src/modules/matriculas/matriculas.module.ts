import { Module } from '@nestjs/common';
import { MatriculasController } from './matriculas.controller';
import { MatriculasService } from './matriculas.service';
import { AuditModule } from '../audit/audit.module';
import { StorageModule } from '../../storage/storage.module';

@Module({
  imports: [AuditModule, StorageModule],
  controllers: [MatriculasController],
  providers: [MatriculasService],
})
export class MatriculasModule {}
