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
import { TurmasService } from './turmas.service';
import { PaginatedTurmasResponseDto, TurmaResponseDto } from './dto/turma-response.dto';
import { CreateTurmaDto } from './dto/create-turma.dto';
import { ListTurmasQueryDto } from './dto/list-turmas-query.dto';
import { UpdateTurmaDto } from './dto/update-turma.dto';
import { UpdateTurmaStatusDto } from './dto/update-turma-status.dto';
import { AcademiaGuard } from '../../../common/guards/academia.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { Roles } from '../../../common/decorators/roles.decorator';
import { requestMetadata } from '../../../common/utils/request-metadata';

/// Tenant-scoped, restrito a ACADEMIA_ADMIN/RECEPCIONISTA — mesmo critério
/// de Modalidades/Feriados (docs/18, decisão confirmada: sem acesso de
/// PROFESSOR nesta fase).
@ApiTags('agenda/turmas')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('agenda/turmas')
export class TurmasController {
  constructor(private readonly service: TurmasService) {}

  @Post()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Cadastra uma turma' })
  create(@Body() dto: CreateTurmaDto, @Req() req: Request): Promise<TurmaResponseDto> {
    return this.service.create(dto, requestMetadata(req));
  }

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Lista turmas, paginado, com pesquisa por nome e filtro de status' })
  list(@Query() query: ListTurmasQueryDto): Promise<PaginatedTurmasResponseDto> {
    return this.service.list(query);
  }

  @Get(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Detalhe de uma turma' })
  findOne(@Param('id', ParseUUIDPipe) id: string): Promise<TurmaResponseDto> {
    return this.service.findOne(id);
  }

  @Patch(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Edita os dados de uma turma' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateTurmaDto,
    @Req() req: Request,
  ): Promise<TurmaResponseDto> {
    return this.service.update(id, dto, requestMetadata(req));
  }

  @Patch(':id/status')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Ativa/inativa uma turma' })
  updateStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateTurmaStatusDto,
    @Req() req: Request,
  ): Promise<TurmaResponseDto> {
    return this.service.updateStatus(id, dto, requestMetadata(req));
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Remove uma turma (soft delete — nunca apagada fisicamente)' })
  async remove(@Param('id', ParseUUIDPipe) id: string, @Req() req: Request): Promise<void> {
    await this.service.remove(id, requestMetadata(req));
  }
}
