import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { DashboardService } from './dashboard.service';
import { DashboardAcademiaResponseDto } from './dto/dashboard-academia-response.dto';
import { AcademiaGuard } from '../../common/guards/academia.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';

/// Dashboard da própria academia — distinto de /admin/dashboard (Sprint 2,
/// SYSTEM_ADMIN, visão cross-tenant).
@ApiTags('dashboard')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('dashboard')
export class DashboardController {
  constructor(private readonly service: DashboardService) {}

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({
    summary:
      'Visão geral da academia: alunos, professores, novos do mês, aniversariantes, usuários',
  })
  get(): Promise<DashboardAcademiaResponseDto> {
    return this.service.get();
  }
}
