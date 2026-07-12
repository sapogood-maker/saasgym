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
import { MatriculasService } from './matriculas.service';
import { MatriculaResponseDto, PaginatedMatriculasResponseDto } from './dto/matricula-response.dto';
import { CreateMatriculaDto } from './dto/create-matricula.dto';
import { ListMatriculasQueryDto } from './dto/list-matriculas-query.dto';
import { UpdateMatriculaDto } from './dto/update-matricula.dto';
import { TrancarMatriculaDto } from './dto/trancar-matricula.dto';
import { CancelarMatriculaDto } from './dto/cancelar-matricula.dto';
import { RenovarMatriculaDto } from './dto/renovar-matricula.dto';
import { AcademiaGuard } from '../../common/guards/academia.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { requestMetadata } from '../../common/utils/request-metadata';

/// Tenant-scoped: mesmo padrão de PlanosController — escrita restrita a
/// ACADEMIA_ADMIN/RECEPCIONISTA; leitura também aberta a PROFESSOR.
/// Transições de status (trancar/reativar/cancelar/renovar) são
/// endpoints dedicados, não um único `/status` genérico — ver comentário
/// em MatriculasService.
@ApiTags('matriculas')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('matriculas')
export class MatriculasController {
  constructor(private readonly service: MatriculasService) {}

  @Post()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Cria uma matrícula (aluno só pode ter 1 ATIVA por vez)' })
  create(@Body() dto: CreateMatriculaDto, @Req() req: Request): Promise<MatriculaResponseDto> {
    return this.service.create(dto, requestMetadata(req));
  }

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA, Role.PROFESSOR)
  @ApiOperation({ summary: 'Lista matrículas, paginado, com filtro por aluno/plano/status' })
  list(@Query() query: ListMatriculasQueryDto): Promise<PaginatedMatriculasResponseDto> {
    return this.service.list(query);
  }

  @Get(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA, Role.PROFESSOR)
  @ApiOperation({ summary: 'Detalhe de uma matrícula' })
  findOne(@Param('id', ParseUUIDPipe) id: string): Promise<MatriculaResponseDto> {
    return this.service.findOne(id);
  }

  @Patch(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Edita valor/diaVencimento — nunca o plano ou o aluno' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateMatriculaDto,
    @Req() req: Request,
  ): Promise<MatriculaResponseDto> {
    return this.service.update(id, dto, requestMetadata(req));
  }

  @Patch(':id/trancar')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Pausa temporariamente uma matrícula ATIVA' })
  trancar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: TrancarMatriculaDto,
    @Req() req: Request,
  ): Promise<MatriculaResponseDto> {
    return this.service.trancar(id, dto, requestMetadata(req));
  }

  @Patch(':id/reativar')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({
    summary: 'Reativa uma matrícula TRANCADA (estende dataFim pelos dias congelados)',
  })
  reativar(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: Request,
  ): Promise<MatriculaResponseDto> {
    return this.service.reativar(id, requestMetadata(req));
  }

  @Patch(':id/cancelar')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Encerra a matrícula por decisão (motivo obrigatório)' })
  cancelar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CancelarMatriculaDto,
    @Req() req: Request,
  ): Promise<MatriculaResponseDto> {
    return this.service.cancelar(id, dto, requestMetadata(req));
  }

  @Post(':id/renovar')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Encerra esta matrícula e cria a próxima, no mesmo plano' })
  renovar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RenovarMatriculaDto,
    @Req() req: Request,
  ): Promise<MatriculaResponseDto> {
    return this.service.renovar(id, dto, requestMetadata(req));
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({
    summary: 'Remove uma matrícula criada por engano (soft delete — não é cancelamento)',
  })
  async remove(@Param('id', ParseUUIDPipe) id: string, @Req() req: Request): Promise<void> {
    await this.service.remove(id, requestMetadata(req));
  }
}
