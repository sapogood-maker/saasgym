import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { RelatoriosService } from './relatorios.service';
import { RelatoriosEvolucaoQueryDto } from './dto/relatorios-evolucao-query.dto';
import { RelatoriosResumoQueryDto } from './dto/relatorios-resumo-query.dto';
import { RelatoriosResumoResponseDto } from './dto/relatorios-resumo-response.dto';
import { RelatoriosAlunosResponseDto } from './dto/relatorios-alunos-response.dto';
import { DashboardEvolucaoResponseDto } from '../financeiro/dashboard/dto/dashboard-evolucao-response.dto';
import { AcademiaGuard } from '../../common/guards/academia.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';

/// Tenant-scoped, restrito a ACADEMIA_ADMIN/RECEPCIONISTA — mesmo critério
/// do Financeiro (dado gerencial, sem acesso de PROFESSOR).
@ApiTags('relatorios')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('relatorios')
export class RelatoriosController {
  constructor(private readonly service: RelatoriosService) {}

  @Get('resumo')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({
    summary: 'Snapshot atual: alunos ativos, cancelamentos no período e retenção aproximada',
  })
  resumo(@Query() query: RelatoriosResumoQueryDto): Promise<RelatoriosResumoResponseDto> {
    return this.service.resumo(query);
  }

  @Get('receita')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Evolução mensal de receita prevista/recebida, despesas e saldo' })
  receita(@Query() query: RelatoriosEvolucaoQueryDto): Promise<DashboardEvolucaoResponseDto> {
    return this.service.receita(query);
  }

  @Get('alunos')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({
    summary: 'Evolução mensal de novos alunos, cancelamentos (por motivo) e saldo líquido',
  })
  alunos(@Query() query: RelatoriosEvolucaoQueryDto): Promise<RelatoriosAlunosResponseDto> {
    return this.service.alunos(query);
  }
}
