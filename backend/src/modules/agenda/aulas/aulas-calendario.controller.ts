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
import { AulasService } from './aulas.service';
import { ListAulasCalendarioQueryDto } from './dto/list-aulas-calendario-query.dto';
import { CancelarAulaDto } from './dto/cancelar-aula.dto';
import { DefinirSubstitutoDto } from './dto/definir-substituto.dto';
import { CreateAulaExtraDto } from './dto/create-aula-extra.dto';
import { AulaResponseDto, PaginatedAulasResponseDto } from './dto/aula-response.dto';
import { AcademiaGuard } from '../../../common/guards/academia.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { Roles } from '../../../common/decorators/roles.decorator';
import { requestMetadata } from '../../../common/utils/request-metadata';

/// Calendário (MS7) — recurso de topo (`agenda/aulas`), não aninhado numa
/// Turma: as consultas aqui cruzam turmas (por professor, por status, por
/// período da academia inteira). `Aula` continua sendo o único fato —
/// este controller só lê/escreve `Aula`, nunca `Recorrencia`/`TurmaAluno`/
/// `AulaAluno` (docs/18, seção 5, "Calendário").
@ApiTags('agenda/aulas')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('agenda/aulas')
export class AulasCalendarioController {
  constructor(private readonly service: AulasService) {}

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Lista aulas da academia, paginado, com filtros de período/turma/professor/modalidade/status' })
  list(@Query() query: ListAulasCalendarioQueryDto): Promise<PaginatedAulasResponseDto> {
    return this.service.listCalendario(query);
  }

  @Get(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Detalhe de uma aula' })
  findOne(@Param('id', ParseUUIDPipe) id: string): Promise<AulaResponseDto> {
    return this.service.findOne(id);
  }

  @Post('extra')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Cria uma aula extra (avulsa, sem recorrência por trás)' })
  criarExtra(@Body() dto: CreateAulaExtraDto, @Req() req: Request): Promise<AulaResponseDto> {
    return this.service.criarExtra(dto, requestMetadata(req));
  }

  @Patch(':id/cancelar')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Cancela uma aula (nunca remove — só muda o status)' })
  cancelar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CancelarAulaDto,
    @Req() req: Request,
  ): Promise<AulaResponseDto> {
    return this.service.cancelar(id, dto, requestMetadata(req));
  }

  @Patch(':id/substituto')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Define um professor substituto pontual para esta aula' })
  definirSubstituto(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: DefinirSubstitutoDto,
    @Req() req: Request,
  ): Promise<AulaResponseDto> {
    return this.service.definirSubstituto(id, dto, requestMetadata(req));
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Remove uma aula (soft delete — correção de cadastro, não cancelamento)' })
  async remove(@Param('id', ParseUUIDPipe) id: string, @Req() req: Request): Promise<void> {
    await this.service.remove(id, requestMetadata(req));
  }
}
