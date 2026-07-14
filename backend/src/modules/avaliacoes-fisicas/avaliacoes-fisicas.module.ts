import { Module } from '@nestjs/common';
import { AvaliacoesFisicasController } from './avaliacoes-fisicas.controller';
import { AvaliacoesFisicasService } from './avaliacoes-fisicas.service';
import { AuditModule } from '../audit/audit.module';

@Module({
  imports: [AuditModule],
  controllers: [AvaliacoesFisicasController],
  providers: [AvaliacoesFisicasService],
})
export class AvaliacoesFisicasModule {}
