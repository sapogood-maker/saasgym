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
import { RecorrenciasService } from './recorrencias.service';
import { CreateRecorrenciaDto } from './dto/create-recorrencia.dto';
import { UpdateRecorrenciaDto } from './dto/update-recorrencia.dto';
import { RecorrenciaResponseDto } from './dto/recorrencia-response.dto';
import { AcademiaGuard } from '../../../common/guards/academia.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { Roles } from '../../../common/decorators/roles.decorator';
import { requestMetadata } from '../../../common/utils/request-metadata';

/// Sempre aninhado numa Turma (`agenda/turmas/:turmaId/recorrencias`) —
/// nunca um recurso de topo próprio, reforçando em código a invariante
/// "Recorrência pertence exclusivamente à Turma" (docs/18, seção 2 item 3).
/// Mesmo critério de acesso de Turmas/Modalidades/Feriados: sem leitura
/// liberada pra PROFESSOR nesta fase.
@ApiTags('agenda/turmas/recorrencias')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('agenda/turmas/:turmaId/recorrencias')
export class RecorrenciasController {
  constructor(private readonly service: RecorrenciasService) {}

  @Post()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Cadastra uma recorrência para a turma' })
  create(
    @Param('turmaId', ParseUUIDPipe) turmaId: string,
    @Body() dto: CreateRecorrenciaDto,
    @Req() req: Request,
  ): Promise<RecorrenciaResponseDto> {
    return this.service.create(turmaId, dto, requestMetadata(req));
  }

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Lista as recorrências da turma' })
  list(@Param('turmaId', ParseUUIDPipe) turmaId: string): Promise<RecorrenciaResponseDto[]> {
    return this.service.list(turmaId);
  }

  @Patch(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Edita uma recorrência da turma' })
  update(
    @Param('turmaId', ParseUUIDPipe) turmaId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateRecorrenciaDto,
    @Req() req: Request,
  ): Promise<RecorrenciaResponseDto> {
    return this.service.update(turmaId, id, dto, requestMetadata(req));
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Remove uma recorrência da turma (soft delete)' })
  async remove(
    @Param('turmaId', ParseUUIDPipe) turmaId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: Request,
  ): Promise<void> {
    await this.service.remove(turmaId, id, requestMetadata(req));
  }
}
