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
import { ModalidadesService } from './modalidades.service';
import {
  ModalidadeResponseDto,
  PaginatedModalidadesResponseDto,
} from './dto/modalidade-response.dto';
import { CreateModalidadeDto } from './dto/create-modalidade.dto';
import { ListModalidadesQueryDto } from './dto/list-modalidades-query.dto';
import { UpdateModalidadeDto } from './dto/update-modalidade.dto';
import { UpdateModalidadeStatusDto } from './dto/update-modalidade-status.dto';
import { AcademiaGuard } from '../../../common/guards/academia.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { Roles } from '../../../common/decorators/roles.decorator';
import { requestMetadata } from '../../../common/utils/request-metadata';

/// Tenant-scoped, restrito a ACADEMIA_ADMIN/RECEPCIONISTA — mesmo critério
/// de Financeiro (docs/18, decisão confirmada: sem acesso de PROFESSOR
/// nesta fase, Professor ainda não tem login próprio).
@ApiTags('agenda/modalidades')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('agenda/modalidades')
export class ModalidadesController {
  constructor(private readonly service: ModalidadesService) {}

  @Post()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Cadastra uma modalidade' })
  create(
    @Body() dto: CreateModalidadeDto,
    @Req() req: Request,
  ): Promise<ModalidadeResponseDto> {
    return this.service.create(dto, requestMetadata(req));
  }

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Lista modalidades, paginado, com pesquisa por nome e filtro de status' })
  list(@Query() query: ListModalidadesQueryDto): Promise<PaginatedModalidadesResponseDto> {
    return this.service.list(query);
  }

  @Get(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Detalhe de uma modalidade' })
  findOne(@Param('id', ParseUUIDPipe) id: string): Promise<ModalidadeResponseDto> {
    return this.service.findOne(id);
  }

  @Patch(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Edita os dados de uma modalidade' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateModalidadeDto,
    @Req() req: Request,
  ): Promise<ModalidadeResponseDto> {
    return this.service.update(id, dto, requestMetadata(req));
  }

  @Patch(':id/status')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Ativa/inativa uma modalidade' })
  updateStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateModalidadeStatusDto,
    @Req() req: Request,
  ): Promise<ModalidadeResponseDto> {
    return this.service.updateStatus(id, dto, requestMetadata(req));
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Remove uma modalidade (soft delete — nunca apagada fisicamente)' })
  async remove(@Param('id', ParseUUIDPipe) id: string, @Req() req: Request): Promise<void> {
    await this.service.remove(id, requestMetadata(req));
  }
}
