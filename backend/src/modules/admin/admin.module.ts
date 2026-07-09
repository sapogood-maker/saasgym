import { Module } from '@nestjs/common';
import { AcademiaProvisioningService } from './academias/academia-provisioning.service';
import { AdminAcademiaConfiguracaoService } from './academias/admin-academia-configuracao.service';
import { AdminAcademiaController } from './academias/admin-academia.controller';
import { AdminAcademiaService } from './academias/admin-academia.service';
import { AdminDashboardController } from './dashboard/admin-dashboard.controller';
import { AdminDashboardService } from './dashboard/admin-dashboard.service';
import { AdminPlanoSaasController } from './planos-saas/admin-plano-saas.controller';
import { AdminPlanoSaasService } from './planos-saas/admin-plano-saas.service';
import { AuditModule } from '../audit/audit.module';
import { StorageModule } from '../../storage/storage.module';

/// Módulo de administração do SaaS — 100% restrito a SYSTEM_ADMIN (ver
/// SystemAdminGuard em cada controller). Nenhum usuário de academia acessa
/// nada aqui.
@Module({
  imports: [AuditModule, StorageModule],
  controllers: [AdminAcademiaController, AdminPlanoSaasController, AdminDashboardController],
  providers: [
    AcademiaProvisioningService,
    AdminAcademiaService,
    AdminAcademiaConfiguracaoService,
    AdminPlanoSaasService,
    AdminDashboardService,
  ],
  exports: [AcademiaProvisioningService],
})
export class AdminModule {}
