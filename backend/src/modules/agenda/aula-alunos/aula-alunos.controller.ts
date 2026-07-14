import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Query, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import type { Request } from 'express';
import { AulaAlunosService } from './aula-alunos.service';
import { RegistrarPresencaDto } from './dto/registrar-presenca.dto';
import { AulaAlunoResponseDto } from './dto/aula-aluno-response.dto';
import { ListFrequenciaQueryDto } from './dto/list-frequencia-query.dto';
import { PaginatedFrequenciaAlunoResponseDto } from './dto/frequencia-aluno-response.dto';
import { AcademiaGuard } from '../../../common/guards/academia.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { Roles } from '../../../common/decorators/roles.decorator';
import { requestMetadata } from '../../../common/utils/request-metadata';

/// Frequência (MS8) — a presença pertence exclusivamente a `AulaAluno`
/// (docs/18, seção 5, "Frequência"). Rotas aninhadas em `Aula` (consulta/
/// registro por ocorrência) e em `Aluno` (histórico cross-aula) — mesmo
/// critério de aninhamento já usado no resto da Agenda.
@ApiTags('agenda/frequencia')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('agenda')
export class AulaAlunosController {
  constructor(private readonly service: AulaAlunosService) {}

  @Get('aulas/:aulaId/alunos')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Lista os alunos vinculados a uma aula, com a presença de cada um' })
  listPorAula(@Param('aulaId', ParseUUIDPipe) aulaId: string): Promise<AulaAlunoResponseDto[]> {
    return this.service.listPorAula(aulaId);
  }

  @Patch('aulas/:aulaId/alunos/:id/presenca')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Registra ou altera a presença de um aluno numa aula já realizada' })
  registrarPresenca(
    @Param('aulaId', ParseUUIDPipe) aulaId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RegistrarPresencaDto,
    @Req() req: Request,
  ): Promise<AulaAlunoResponseDto> {
    return this.service.registrarPresenca(aulaId, id, dto, requestMetadata(req));
  }

  @Get('alunos/:alunoId/frequencia')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Histórico de frequência de um aluno, paginado, com filtro de período' })
  listPorAluno(
    @Param('alunoId', ParseUUIDPipe) alunoId: string,
    @Query() query: ListFrequenciaQueryDto,
  ): Promise<PaginatedFrequenciaAlunoResponseDto> {
    return this.service.listPorAluno(alunoId, query);
  }
}
