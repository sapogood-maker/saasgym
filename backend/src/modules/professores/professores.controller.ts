import {
  BadRequestException,
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
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import type { Request } from 'express';
import { CreateProfessorDto } from './dto/create-professor.dto';
import { ListProfessoresQueryDto } from './dto/list-professores-query.dto';
import {
  PaginatedProfessoresResponseDto,
  ProfessorResponseDto,
} from './dto/professor-response.dto';
import { UpdateProfessorDto } from './dto/update-professor.dto';
import { UpdateProfessorStatusDto } from './dto/update-professor-status.dto';
import { ProfessoresService } from './professores.service';
import { AcademiaGuard } from '../../common/guards/academia.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { ImageFileInterceptor } from '../../common/upload/image-file-interceptor';
import { requestMetadata } from '../../common/utils/request-metadata';

/// Mesmo padrão de permissões de AlunosController (ver lá).
@ApiTags('professores')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('professores')
export class ProfessoresController {
  constructor(private readonly service: ProfessoresService) {}

  @Post()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Cadastra um professor' })
  create(@Body() dto: CreateProfessorDto, @Req() req: Request): Promise<ProfessorResponseDto> {
    return this.service.create(dto, requestMetadata(req));
  }

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA, Role.PROFESSOR)
  @ApiOperation({
    summary: 'Lista professores, paginado, com pesquisa (nome/CPF/telefone) e filtro de status',
  })
  list(@Query() query: ListProfessoresQueryDto): Promise<PaginatedProfessoresResponseDto> {
    return this.service.list(query);
  }

  @Get(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA, Role.PROFESSOR)
  @ApiOperation({ summary: 'Detalhe de um professor' })
  findOne(@Param('id', ParseUUIDPipe) id: string): Promise<ProfessorResponseDto> {
    return this.service.findOne(id);
  }

  @Patch(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Edita os dados de um professor' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateProfessorDto,
    @Req() req: Request,
  ): Promise<ProfessorResponseDto> {
    return this.service.update(id, dto, requestMetadata(req));
  }

  @Patch(':id/status')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Ativa/inativa um professor' })
  updateStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateProfessorStatusDto,
    @Req() req: Request,
  ): Promise<ProfessorResponseDto> {
    return this.service.updateStatus(id, dto, requestMetadata(req));
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Remove um professor (soft delete — nunca apagado fisicamente)' })
  async remove(@Param('id', ParseUUIDPipe) id: string, @Req() req: Request): Promise<void> {
    await this.service.remove(id, requestMetadata(req));
  }

  @Post(':id/foto')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Upload da foto do professor (PNG/JPEG/WebP, até 2MB)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' } } },
  })
  @UseInterceptors(ImageFileInterceptor())
  async uploadFoto(
    @Param('id', ParseUUIDPipe) id: string,
    @UploadedFile() file: Express.Multer.File | undefined,
    @Req() req: Request,
  ): Promise<ProfessorResponseDto> {
    if (!file) {
      throw new BadRequestException('Nenhum arquivo enviado');
    }
    return this.service.uploadFoto(id, file, requestMetadata(req));
  }
}
