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
import { MensalidadesService } from './mensalidades.service';
import { GerarMensalidadesDto } from './dto/gerar-mensalidades.dto';
import { ListMensalidadesQueryDto } from './dto/list-mensalidades-query.dto';
import { UpdateMensalidadeDto } from './dto/update-mensalidade.dto';
import { MarcarPagaMensalidadeDto } from './dto/marcar-paga-mensalidade.dto';
import { CancelarMensalidadeDto } from './dto/cancelar-mensalidade.dto';
import {
  GerarMensalidadesResponseDto,
  MensalidadeResponseDto,
  PaginatedMensalidadesResponseDto,
} from './dto/mensalidade-response.dto';
import { AcademiaGuard } from '../../../common/guards/academia.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { Roles } from '../../../common/decorators/roles.decorator';
import { requestMetadata } from '../../../common/utils/request-metadata';

/// Tenant-scoped, restrito a ACADEMIA_ADMIN/RECEPCIONISTA — diferente de
/// Planos/Matrículas, PROFESSOR não tem acesso aqui (dado financeiro da
/// academia, não operacional do dia a dia de aula).
@ApiTags('financeiro/mensalidades')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('financeiro/mensalidades')
export class MensalidadesController {
  constructor(private readonly service: MensalidadesService) {}

  @Post('gerar')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Gera as mensalidades do mês (idempotente — não duplica)' })
  gerar(
    @Body() dto: GerarMensalidadesDto,
    @Req() req: Request,
  ): Promise<GerarMensalidadesResponseDto> {
    return this.service.gerar(dto, requestMetadata(req));
  }

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({
    summary: 'Lista mensalidades, paginado, com filtro por matrícula/aluno/status/mês',
  })
  list(@Query() query: ListMensalidadesQueryDto): Promise<PaginatedMensalidadesResponseDto> {
    return this.service.list(query);
  }

  @Get(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Detalhe de uma mensalidade' })
  findOne(@Param('id', ParseUUIDPipe) id: string): Promise<MensalidadeResponseDto> {
    return this.service.findOne(id);
  }

  @Patch(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Edita desconto/multa/vencimento — só enquanto PENDENTE' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateMensalidadeDto,
    @Req() req: Request,
  ): Promise<MensalidadeResponseDto> {
    return this.service.update(id, dto, requestMetadata(req));
  }

  @Patch(':id/pagar')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Marca como paga e gera o lançamento de receita correspondente' })
  marcarPaga(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: MarcarPagaMensalidadeDto,
    @Req() req: Request,
  ): Promise<MensalidadeResponseDto> {
    return this.service.marcarPaga(id, dto, requestMetadata(req));
  }

  @Patch(':id/cancelar')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Cancela uma mensalidade PENDENTE (cobrança gerada por engano, etc.)' })
  cancelar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CancelarMensalidadeDto,
    @Req() req: Request,
  ): Promise<MensalidadeResponseDto> {
    return this.service.cancelar(id, dto, requestMetadata(req));
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Remove uma mensalidade criada por engano (bloqueado se já PAGA)' })
  async remove(@Param('id', ParseUUIDPipe) id: string, @Req() req: Request): Promise<void> {
    await this.service.remove(id, requestMetadata(req));
  }
}
