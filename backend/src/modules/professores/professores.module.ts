import { Module } from '@nestjs/common';
import { ProfessoresController } from './professores.controller';
import { ProfessoresService } from './professores.service';
import { AuditModule } from '../audit/audit.module';
import { StorageModule } from '../../storage/storage.module';

@Module({
  imports: [AuditModule, StorageModule],
  controllers: [ProfessoresController],
  providers: [ProfessoresService],
})
export class ProfessoresModule {}
