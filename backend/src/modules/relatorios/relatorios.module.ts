import { Module } from '@nestjs/common';
import { RelatoriosController } from './relatorios.controller';
import { RelatoriosService } from './relatorios.service';
import { FinanceiroModule } from '../financeiro/financeiro.module';

/// Só orquestra dado que já existe em outros módulos (Financeiro,
/// Matrículas via PrismaService) — mesmo padrão de composição do
/// DashboardModule, sem regra de negócio nova própria.
@Module({
  imports: [FinanceiroModule],
  controllers: [RelatoriosController],
  providers: [RelatoriosService],
})
export class RelatoriosModule {}
