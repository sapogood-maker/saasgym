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
import { PlanosService } from './planos.service';
import { PaginatedPlanosResponseDto, PlanoResponseDto } from './dto/plano-response.dto';
import { CreatePlanoDto } from './dto/create-plano.dto';
import { ListPlanosQueryDto } from './dto/list-planos-query.dto';
import { UpdatePlanoDto } from './dto/update-plano.dto';
import { UpdatePlanoStatusDto } from './dto/update-plano-status.dto';
import { AcademiaGuard } from '../../common/guards/academia.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { requestMetadata } from '../../common/utils/request-metadata';

/// Tenant-scoped: mesmo padrão de AlunosController/ProfessoresController —
/// escrita restrita a ACADEMIA_ADMIN/RECEPCIONISTA; leitura também aberta
/// a PROFESSOR (precisa ver os planos pra orientar o aluno na matrícula).
@ApiTags('planos')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('planos')
export class PlanosController {
  constructor(private readonly service: PlanosService) {}

  @Post()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Cadastra um plano' })
  create(@Body() dto: CreatePlanoDto, @Req() req: Request): Promise<PlanoResponseDto> {
    return this.service.create(dto, requestMetadata(req));
  }

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA, Role.PROFESSOR)
  @ApiOperation({ summary: 'Lista planos, paginado, com pesquisa por nome e filtro de status' })
  list(@Query() query: ListPlanosQueryDto): Promise<PaginatedPlanosResponseDto> {
    return this.service.list(query);
  }

  @Get(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA, Role.PROFESSOR)
  @ApiOperation({ summary: 'Detalhe de um plano' })
  findOne(@Param('id', ParseUUIDPipe) id: string): Promise<PlanoResponseDto> {
    return this.service.findOne(id);
  }

  @Patch(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Edita os dados de um plano' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdatePlanoDto,
    @Req() req: Request,
  ): Promise<PlanoResponseDto> {
    return this.service.update(id, dto, requestMetadata(req));
  }

  @Patch(':id/status')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Ativa/inativa um plano' })
  updateStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdatePlanoStatusDto,
    @Req() req: Request,
  ): Promise<PlanoResponseDto> {
    return this.service.updateStatus(id, dto, requestMetadata(req));
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Remove um plano (soft delete — nunca apagado fisicamente)' })
  async remove(@Param('id', ParseUUIDPipe) id: string, @Req() req: Request): Promise<void> {
    await this.service.remove(id, requestMetadata(req));
  }
}
