import { Module } from '@nestjs/common';
import { MensalidadesController } from './mensalidades/mensalidades.controller';
import { MensalidadesService } from './mensalidades/mensalidades.service';
import { LancamentosController } from './lancamentos/lancamentos.controller';
import { LancamentosService } from './lancamentos/lancamentos.service';
import { DashboardFinanceiroController } from './dashboard/dashboard-financeiro.controller';
import { DashboardFinanceiroService } from './dashboard/dashboard-financeiro.service';
import { AuditModule } from '../audit/audit.module';

/// Agrupa Mensalidades + Lançamentos + Dashboard num único módulo Nest
/// (mesmo padrão de AdminModule agregando academias/dashboard/planos-saas)
/// — subpastas são só organização de arquivo, não módulos Nest próprios.
/// `DashboardFinanceiroService` só orquestra os outros dois (injeta
/// `MensalidadesService`/`LancamentosService` diretamente) — por isso
/// precisa estar no mesmo módulo, sem imports extras.
@Module({
  imports: [AuditModule],
  controllers: [MensalidadesController, LancamentosController, DashboardFinanceiroController],
  providers: [MensalidadesService, LancamentosService, DashboardFinanceiroService],
})
export class FinanceiroModule {}
