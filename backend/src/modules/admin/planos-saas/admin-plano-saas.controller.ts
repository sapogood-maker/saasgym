import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PlanoSaas } from '@prisma/client';
import type { Request } from 'express';
import { AdminPlanoSaasService } from './admin-plano-saas.service';
import { CreatePlanoSaasDto } from './dto/create-plano-saas.dto';
import { PlanoSaasResponseDto } from './dto/plano-saas-response.dto';
import { UpdatePlanoSaasDto } from './dto/update-plano-saas.dto';
import { SystemAdminGuard } from '../../../common/guards/system-admin.guard';
import { requestMetadata } from '../../../common/utils/request-metadata';

/// 100% restrito a SYSTEM_ADMIN — nenhum usuário de academia acessa nada
/// aqui (ver docs/13-admin-saas.md).
@ApiTags('admin/planos-saas')
@ApiBearerAuth()
@UseGuards(SystemAdminGuard)
@Controller('admin/planos-saas')
export class AdminPlanoSaasController {
  constructor(private readonly service: AdminPlanoSaasService) {}

  @Post()
  @ApiOperation({ summary: 'Cria um plano do catálogo do SaaS' })
  async create(
    @Body() dto: CreatePlanoSaasDto,
    @Req() req: Request,
  ): Promise<PlanoSaasResponseDto> {
    return this.toResponse(await this.service.create(dto, requestMetadata(req)));
  }

  @Get()
  @ApiOperation({ summary: 'Lista todos os planos do catálogo (ativos e inativos)' })
  async list(): Promise<PlanoSaasResponseDto[]> {
    return (await this.service.list()).map((plano) => this.toResponse(plano));
  }

  @Get(':id')
  @ApiOperation({ summary: 'Detalhe de um plano' })
  async findOne(@Param('id', ParseUUIDPipe) id: string): Promise<PlanoSaasResponseDto> {
    return this.toResponse(await this.service.findOne(id));
  }

  @Patch(':id')
  @ApiOperation({
    summary: 'Edita um plano (inclusive desativar via ativo:false — não há delete)',
  })
  async update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdatePlanoSaasDto,
    @Req() req: Request,
  ): Promise<PlanoSaasResponseDto> {
    return this.toResponse(await this.service.update(id, dto, requestMetadata(req)));
  }

  private toResponse(plano: PlanoSaas): PlanoSaasResponseDto {
    return {
      id: plano.id,
      nome: plano.nome,
      ativo: plano.ativo,
      ordem: plano.ordem,
      limiteAlunos: plano.limiteAlunos,
      limiteProfessores: plano.limiteProfessores,
      limiteUsuarios: plano.limiteUsuarios,
      limiteArmazenamentoMb: plano.limiteArmazenamentoMb,
      limiteBackups: plano.limiteBackups,
      funcionalidades: plano.funcionalidades as Record<string, unknown> | null,
    };
  }
}
