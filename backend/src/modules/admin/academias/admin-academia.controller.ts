import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Academia } from '@prisma/client';
import type { Request } from 'express';
import { AdminAcademiaConfiguracaoService } from './admin-academia-configuracao.service';
import { AdminAcademiaService } from './admin-academia.service';
import { AcademiaConfiguracaoResponseDto } from './dto/academia-configuracao-response.dto';
import { AcademiaResponseDto, PaginatedAcademiasResponseDto } from './dto/academia-response.dto';
import { CreateAcademiaDto } from './dto/create-academia.dto';
import { ListAcademiasQueryDto } from './dto/list-academias-query.dto';
import { UpdateAcademiaDto } from './dto/update-academia.dto';
import { UpdateAcademiaConfiguracaoDto } from './dto/update-academia-configuracao.dto';
import { UpdateAcademiaStatusDto } from './dto/update-academia-status.dto';
import { SystemAdminGuard } from '../../../common/guards/system-admin.guard';
import { ImageFileInterceptor } from '../../../common/upload/image-file-interceptor';
import { requestMetadata } from '../../../common/utils/request-metadata';

/// 100% restrito a SYSTEM_ADMIN — nenhum usuário de academia acessa nada
/// aqui (ver docs/13-admin-saas.md).
@ApiTags('admin/academias')
@ApiBearerAuth()
@UseGuards(SystemAdminGuard)
@Controller('admin/academias')
export class AdminAcademiaController {
  constructor(
    private readonly service: AdminAcademiaService,
    private readonly configuracaoService: AdminAcademiaConfiguracaoService,
  ) {}

  @Post()
  @ApiOperation({
    summary: 'Cria uma academia + seu primeiro ACADEMIA_ADMIN, numa única transação',
  })
  async create(
    @Body() dto: CreateAcademiaDto,
    @Req() req: Request,
  ): Promise<AcademiaResponseDto> {
    const academia = await this.service.create(dto, requestMetadata(req));
    return this.toResponse(academia);
  }

  @Get()
  @ApiOperation({ summary: 'Lista academias, paginado, com filtro opcional por status' })
  async list(@Query() query: ListAcademiasQueryDto): Promise<PaginatedAcademiasResponseDto> {
    const result = await this.service.list(query);
    return { ...result, items: result.items.map((academia) => this.toResponse(academia)) };
  }

  @Get(':id')
  @ApiOperation({ summary: 'Detalhe de uma academia' })
  async findOne(@Param('id', ParseUUIDPipe) id: string): Promise<AcademiaResponseDto> {
    return this.toResponse(await this.service.findOne(id));
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Edita os campos cadastrais de uma academia' })
  async update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateAcademiaDto,
    @Req() req: Request,
  ): Promise<AcademiaResponseDto> {
    return this.toResponse(await this.service.update(id, dto, requestMetadata(req)));
  }

  @Patch(':id/status')
  @ApiOperation({
    summary:
      'Transiciona o status da academia — entrar num status bloqueante revoga em cascata todas as sessões ativas dos usuários dela',
  })
  async updateStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateAcademiaStatusDto,
    @Req() req: Request,
  ): Promise<AcademiaResponseDto> {
    return this.toResponse(await this.service.updateStatus(id, dto, requestMetadata(req)));
  }

  @Get(':id/configuracao')
  @ApiOperation({ summary: 'Branding/configuração da academia' })
  getConfiguracao(
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<AcademiaConfiguracaoResponseDto> {
    return this.configuracaoService.get(id);
  }

  @Put(':id/configuracao')
  @ApiOperation({ summary: 'Atualiza o branding/configuração da academia' })
  updateConfiguracao(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateAcademiaConfiguracaoDto,
    @Req() req: Request,
  ): Promise<AcademiaConfiguracaoResponseDto> {
    return this.configuracaoService.update(id, dto, requestMetadata(req));
  }

  @Post(':id/logo')
  @ApiOperation({ summary: 'Upload do logotipo da academia (PNG/JPEG/WebP, até 2MB)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' } } },
  })
  @UseInterceptors(ImageFileInterceptor())
  async uploadLogo(
    @Param('id', ParseUUIDPipe) id: string,
    @UploadedFile() file: Express.Multer.File | undefined,
    @Req() req: Request,
  ): Promise<AcademiaConfiguracaoResponseDto> {
    if (!file) {
      throw new BadRequestException('Nenhum arquivo enviado');
    }
    return this.configuracaoService.updateLogo(id, file, requestMetadata(req));
  }

  private toResponse(academia: Academia): AcademiaResponseDto {
    return {
      id: academia.id,
      nome: academia.nome,
      cnpj: academia.cnpj,
      email: academia.email,
      telefone: academia.telefone,
      endereco: academia.endereco,
      dominio: academia.dominio,
      status: academia.status,
      trialExpiresAt: academia.trialExpiresAt,
      planoSaasId: academia.planoSaasId,
      createdAt: academia.createdAt,
    };
  }
}
