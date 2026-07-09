import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AdminDashboardService } from './admin-dashboard.service';
import { DashboardResponseDto } from './dto/dashboard-response.dto';
import { SystemAdminGuard } from '../../../common/guards/system-admin.guard';

/// 100% restrito a SYSTEM_ADMIN — nenhum usuário de academia acessa nada
/// aqui (ver docs/13-admin-saas.md).
@ApiTags('admin/dashboard')
@ApiBearerAuth()
@UseGuards(SystemAdminGuard)
@Controller('admin/dashboard')
export class AdminDashboardController {
  constructor(private readonly service: AdminDashboardService) {}

  @Get()
  @ApiOperation({ summary: 'Visão geral do SaaS: academias por status, armazenamento, versão' })
  get(): Promise<DashboardResponseDto> {
    return this.service.get();
  }
}
