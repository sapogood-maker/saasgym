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
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Academia } from '@prisma/client';
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

const LOGO_MIME_TYPES = ['image/png', 'image/jpeg', 'image/webp'];
const LOGO_MAX_SIZE_BYTES = 2 * 1024 * 1024;

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
  async create(@Body() dto: CreateAcademiaDto): Promise<AcademiaResponseDto> {
    const academia = await this.service.create(dto);
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
  ): Promise<AcademiaResponseDto> {
    return this.toResponse(await this.service.update(id, dto));
  }

  @Patch(':id/status')
  @ApiOperation({
    summary:
      'Transiciona o status da academia — entrar num status bloqueante revoga em cascata todas as sessões ativas dos usuários dela',
  })
  async updateStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateAcademiaStatusDto,
  ): Promise<AcademiaResponseDto> {
    return this.toResponse(await this.service.updateStatus(id, dto));
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
  ): Promise<AcademiaConfiguracaoResponseDto> {
    return this.configuracaoService.update(id, dto);
  }

  @Post(':id/logo')
  @ApiOperation({ summary: 'Upload do logotipo da academia (PNG/JPEG/WebP, até 2MB)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' } } },
  })
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: LOGO_MAX_SIZE_BYTES },
      fileFilter: (_req, file, callback) => {
        if (!LOGO_MIME_TYPES.includes(file.mimetype)) {
          callback(new BadRequestException('Formato não suportado — use PNG, JPEG ou WebP'), false);
          return;
        }
        callback(null, true);
      },
    }),
  )
  async uploadLogo(
    @Param('id', ParseUUIDPipe) id: string,
    @UploadedFile() file: Express.Multer.File | undefined,
  ): Promise<AcademiaConfiguracaoResponseDto> {
    if (!file) {
      throw new BadRequestException('Nenhum arquivo enviado');
    }
    return this.configuracaoService.updateLogo(id, file);
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
