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
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import type { Request } from 'express';
import { TurmaAlunosService } from './turma-alunos.service';
import { CreateTurmaAlunoDto } from './dto/create-turma-aluno.dto';
import { UpdateTurmaAlunoStatusDto } from './dto/update-turma-aluno-status.dto';
import { TurmaAlunoResponseDto } from './dto/turma-aluno-response.dto';
import { AcademiaGuard } from '../../../common/guards/academia.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { Roles } from '../../../common/decorators/roles.decorator';
import { requestMetadata } from '../../../common/utils/request-metadata';

/// Sempre aninhado numa Turma (`agenda/turmas/:turmaId/alunos`) — mesmo
/// critério de `Recorrencia`. Mesmo acesso de Turmas/Modalidades/Feriados:
/// sem leitura liberada pra PROFESSOR nesta fase.
@ApiTags('agenda/turmas/alunos')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('agenda/turmas/:turmaId/alunos')
export class TurmaAlunosController {
  constructor(private readonly service: TurmaAlunosService) {}

  @Post()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Inscreve um aluno na turma' })
  create(
    @Param('turmaId', ParseUUIDPipe) turmaId: string,
    @Body() dto: CreateTurmaAlunoDto,
    @Req() req: Request,
  ): Promise<TurmaAlunoResponseDto> {
    return this.service.create(turmaId, dto, requestMetadata(req));
  }

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Lista os alunos inscritos na turma' })
  list(@Param('turmaId', ParseUUIDPipe) turmaId: string): Promise<TurmaAlunoResponseDto[]> {
    return this.service.list(turmaId);
  }

  @Patch(':id/status')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Ativa/inativa a inscrição de um aluno na turma' })
  updateStatus(
    @Param('turmaId', ParseUUIDPipe) turmaId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateTurmaAlunoStatusDto,
    @Req() req: Request,
  ): Promise<TurmaAlunoResponseDto> {
    return this.service.updateStatus(turmaId, id, dto, requestMetadata(req));
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Remove a inscrição do aluno na turma (soft delete — correção de cadastro)' })
  async remove(
    @Param('turmaId', ParseUUIDPipe) turmaId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: Request,
  ): Promise<void> {
    await this.service.remove(turmaId, id, requestMetadata(req));
  }
}
