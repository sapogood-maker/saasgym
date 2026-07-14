import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import type { Request } from 'express';
import { AulasService } from './aulas.service';
import { GerarAulasDto } from './dto/gerar-aulas.dto';
import { GerarAulasResponseDto } from './dto/gerar-aulas-response.dto';
import { ListAulasQueryDto } from './dto/list-aulas-query.dto';
import { PaginatedAulasResponseDto } from './dto/aula-response.dto';
import { AcademiaGuard } from '../../../common/guards/academia.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { Roles } from '../../../common/decorators/roles.decorator';
import { requestMetadata } from '../../../common/utils/request-metadata';

/// Sempre aninhado numa Turma (`agenda/turmas/:turmaId/aulas`), mesmo
/// critério de Recorrencia/TurmaAluno. Só geração + leitura nesta fase
/// (MS6) — cancelamento/professor substituto/aula extra ficam pro MS7.
@ApiTags('agenda/turmas/aulas')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('agenda/turmas/:turmaId/aulas')
export class AulasController {
  constructor(private readonly service: AulasService) {}

  @Post('gerar')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Gera as aulas da turma para o período informado (determinístico e idempotente)' })
  gerar(
    @Param('turmaId', ParseUUIDPipe) turmaId: string,
    @Body() dto: GerarAulasDto,
    @Req() req: Request,
  ): Promise<GerarAulasResponseDto> {
    return this.service.gerar(turmaId, dto, requestMetadata(req));
  }

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Lista as aulas da turma, paginado, com filtro opcional de período' })
  list(
    @Param('turmaId', ParseUUIDPipe) turmaId: string,
    @Query() query: ListAulasQueryDto,
  ): Promise<PaginatedAulasResponseDto> {
    return this.service.list(turmaId, query);
  }
}
