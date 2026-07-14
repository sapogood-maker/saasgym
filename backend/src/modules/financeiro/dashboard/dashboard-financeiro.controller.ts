import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { DashboardFinanceiroService } from './dashboard-financeiro.service';
import { DashboardResumoQueryDto } from './dto/dashboard-resumo-query.dto';
import { DashboardResumoResponseDto } from './dto/dashboard-resumo-response.dto';
import { DashboardEvolucaoQueryDto } from './dto/dashboard-evolucao-query.dto';
import { DashboardEvolucaoResponseDto } from './dto/dashboard-evolucao-response.dto';
import { AcademiaGuard } from '../../../common/guards/academia.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { Roles } from '../../../common/decorators/roles.decorator';

/// Tenant-scoped, restrito a ACADEMIA_ADMIN/RECEPCIONISTA — mesmo motivo
/// de MensalidadesController/LancamentosController (dado financeiro, sem
/// acesso de PROFESSOR).
@ApiTags('financeiro/dashboard')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('financeiro/dashboard')
export class DashboardFinanceiroController {
  constructor(private readonly service: DashboardFinanceiroService) {}

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({
    summary:
      'Indicadores do Painel Financeiro (mês selecionado): receita prevista/recebida, despesas, saldo, inadimplência',
  })
  resumo(@Query() query: DashboardResumoQueryDto): Promise<DashboardResumoResponseDto> {
    return this.service.resumo(query);
  }

  @Get('evolucao')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({
    summary: 'Evolução mensal (últimos N meses): receita prevista/recebida, despesas, saldo por mês',
  })
  evolucao(@Query() query: DashboardEvolucaoQueryDto): Promise<DashboardEvolucaoResponseDto> {
    return this.service.evolucao(query);
  }
}
