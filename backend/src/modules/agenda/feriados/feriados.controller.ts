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
import { FeriadosService } from './feriados.service';
import { FeriadoResponseDto, PaginatedFeriadosResponseDto } from './dto/feriado-response.dto';
import { CreateFeriadoDto } from './dto/create-feriado.dto';
import { UpdateFeriadoDto } from './dto/update-feriado.dto';
import { ListFeriadosQueryDto } from './dto/list-feriados-query.dto';
import { AcademiaGuard } from '../../../common/guards/academia.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { Roles } from '../../../common/decorators/roles.decorator';
import { requestMetadata } from '../../../common/utils/request-metadata';

/// Tenant-scoped, restrito a ACADEMIA_ADMIN/RECEPCIONISTA — mesmo critério
/// de Financeiro/Modalidades (docs/18, decisão confirmada).
@ApiTags('agenda/feriados')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('agenda/feriados')
export class FeriadosController {
  constructor(private readonly service: FeriadosService) {}

  @Post()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Cadastra um feriado' })
  create(@Body() dto: CreateFeriadoDto, @Req() req: Request): Promise<FeriadoResponseDto> {
    return this.service.create(dto, requestMetadata(req));
  }

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Lista feriados, paginado, ordenado por data' })
  list(@Query() query: ListFeriadosQueryDto): Promise<PaginatedFeriadosResponseDto> {
    return this.service.list(query);
  }

  @Get(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Detalhe de um feriado' })
  findOne(@Param('id', ParseUUIDPipe) id: string): Promise<FeriadoResponseDto> {
    return this.service.findOne(id);
  }

  @Patch(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Edita os dados de um feriado' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateFeriadoDto,
    @Req() req: Request,
  ): Promise<FeriadoResponseDto> {
    return this.service.update(id, dto, requestMetadata(req));
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Remove um feriado (soft delete — nunca apagado fisicamente)' })
  async remove(@Param('id', ParseUUIDPipe) id: string, @Req() req: Request): Promise<void> {
    await this.service.remove(id, requestMetadata(req));
  }
}
