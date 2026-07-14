import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import type { Request } from 'express';
import { AvaliacoesFisicasService } from './avaliacoes-fisicas.service';
import { CreateAvaliacaoFisicaDto } from './dto/create-avaliacao-fisica.dto';
import { ListAvaliacoesFisicasQueryDto } from './dto/list-avaliacoes-fisicas-query.dto';
import {
  AvaliacaoFisicaResponseDto,
  PaginatedAvaliacoesFisicasResponseDto,
} from './dto/avaliacao-fisica-response.dto';
import { AcademiaGuard } from '../../common/guards/academia.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { requestMetadata } from '../../common/utils/request-metadata';

/// Avaliação Física (Módulo 5) — sempre aninhada em `Aluno` (docs/20,
/// decisão 4), sem trava de role além do staff comum da academia (decisão
/// de negócio confirmada: ACADEMIA_ADMIN/RECEPCIONISTA/PROFESSOR podem
/// registrar, sem exigir vínculo com um cadastro de Professor).
@ApiTags('alunos/avaliacoes-fisicas')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('alunos/:alunoId/avaliacoes-fisicas')
export class AvaliacoesFisicasController {
  constructor(private readonly service: AvaliacoesFisicasService) {}

  @Post()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA, Role.PROFESSOR)
  @ApiOperation({ summary: 'Registra uma avaliação física do aluno' })
  create(
    @Param('alunoId', ParseUUIDPipe) alunoId: string,
    @Body() dto: CreateAvaliacaoFisicaDto,
    @Req() req: Request,
  ): Promise<AvaliacaoFisicaResponseDto> {
    return this.service.create(alunoId, dto, requestMetadata(req));
  }

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA, Role.PROFESSOR)
  @ApiOperation({ summary: 'Histórico de avaliações físicas do aluno, paginado, mais recente primeiro' })
  list(
    @Param('alunoId', ParseUUIDPipe) alunoId: string,
    @Query() query: ListAvaliacoesFisicasQueryDto,
  ): Promise<PaginatedAvaliacoesFisicasResponseDto> {
    return this.service.list(alunoId, query);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA, Role.PROFESSOR)
  @ApiOperation({ summary: 'Remove uma avaliação física (soft delete — correção de erro de cadastro)' })
  async remove(
    @Param('alunoId', ParseUUIDPipe) alunoId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: Request,
  ): Promise<void> {
    await this.service.remove(alunoId, id, requestMetadata(req));
  }
}
