import { Module } from '@nestjs/common';
import { DashboardController } from './dashboard.controller';
import { DashboardService } from './dashboard.service';
import { AgendaModule } from '../agenda/agenda.module';
import { FinanceiroModule } from '../financeiro/financeiro.module';

@Module({
  imports: [AgendaModule, FinanceiroModule],
  controllers: [DashboardController],
  providers: [DashboardService],
})
export class DashboardModule {}
