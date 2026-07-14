import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import type { Request } from 'express';
import { LancamentosService } from './lancamentos.service';
import { CreateLancamentoDto } from './dto/create-lancamento.dto';
import { UpdateLancamentoDto } from './dto/update-lancamento.dto';
import { ListLancamentosQueryDto } from './dto/list-lancamentos-query.dto';
import { ResumoLancamentosQueryDto } from './dto/resumo-lancamentos-query.dto';
import {
  LancamentoResponseDto,
  PaginatedLancamentosResponseDto,
} from './dto/lancamento-response.dto';
import { ResumoLancamentosResponseDto } from './dto/resumo-lancamentos-response.dto';
import { AcademiaGuard } from '../../../common/guards/academia.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { Roles } from '../../../common/decorators/roles.decorator';
import { requestMetadata } from '../../../common/utils/request-metadata';

/// Tenant-scoped, restrito a ACADEMIA_ADMIN/RECEPCIONISTA — mesmo motivo
/// de MensalidadesController (dado financeiro, sem acesso de PROFESSOR).
@ApiTags('financeiro/lancamentos')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('financeiro/lancamentos')
export class LancamentosController {
  constructor(private readonly service: LancamentosService) {}

  @Post()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Registra uma receita/despesa manual' })
  create(@Body() dto: CreateLancamentoDto, @Req() req: Request): Promise<LancamentoResponseDto> {
    return this.service.create(dto, requestMetadata(req));
  }

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Lista lançamentos, paginado, com filtro por tipo e intervalo de data' })
  list(@Query() query: ListLancamentosQueryDto): Promise<PaginatedLancamentosResponseDto> {
    return this.service.list(query);
  }

  @Get('resumo')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({
    summary: 'Resumo financeiro do período (Caixa): totais/quantidades de receita e despesa, saldo',
  })
  resumo(@Query() query: ResumoLancamentosQueryDto): Promise<ResumoLancamentosResponseDto> {
    return this.service.resumo(query);
  }

  @Get(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Detalhe de um lançamento' })
  findOne(@Param('id', ParseUUIDPipe) id: string): Promise<LancamentoResponseDto> {
    return this.service.findOne(id);
  }

  @Patch(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Edita um lançamento manual (bloqueado se gerado por uma mensalidade)' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateLancamentoDto,
    @Req() req: Request,
  ): Promise<LancamentoResponseDto> {
    return this.service.update(id, dto, requestMetadata(req));
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({
    summary: 'Remove um lançamento manual (bloqueado se gerado por uma mensalidade)',
  })
  async remove(@Param('id', ParseUUIDPipe) id: string, @Req() req: Request): Promise<void> {
    await this.service.remove(id, requestMetadata(req));
  }
}
