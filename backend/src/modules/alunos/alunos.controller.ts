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
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { AlunosService } from './alunos.service';
import { AlunoResponseDto, PaginatedAlunosResponseDto } from './dto/aluno-response.dto';
import { CreateAlunoDto } from './dto/create-aluno.dto';
import { ListAlunosQueryDto } from './dto/list-alunos-query.dto';
import { UpdateAlunoDto } from './dto/update-aluno.dto';
import { UpdateAlunoStatusDto } from './dto/update-aluno-status.dto';
import { AcademiaGuard } from '../../common/guards/academia.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { ImageFileInterceptor } from '../../common/upload/image-file-interceptor';

/// Tenant-scoped: exige AcademiaGuard (bloqueia SYSTEM_ADMIN) + RolesGuard.
/// Escrita restrita a ACADEMIA_ADMIN/RECEPCIONISTA; leitura também aberta a
/// PROFESSOR (precisa ver os próprios alunos).
@ApiTags('alunos')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('alunos')
export class AlunosController {
  constructor(private readonly service: AlunosService) {}

  @Post()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Cadastra um aluno' })
  create(@Body() dto: CreateAlunoDto): Promise<AlunoResponseDto> {
    return this.service.create(dto);
  }

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA, Role.PROFESSOR)
  @ApiOperation({
    summary: 'Lista alunos, paginado, com pesquisa (nome/CPF/telefone) e filtro de status',
  })
  list(@Query() query: ListAlunosQueryDto): Promise<PaginatedAlunosResponseDto> {
    return this.service.list(query);
  }

  @Get(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA, Role.PROFESSOR)
  @ApiOperation({ summary: 'Detalhe de um aluno' })
  findOne(@Param('id', ParseUUIDPipe) id: string): Promise<AlunoResponseDto> {
    return this.service.findOne(id);
  }

  @Patch(':id')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Edita os dados de um aluno' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateAlunoDto,
  ): Promise<AlunoResponseDto> {
    return this.service.update(id, dto);
  }

  @Patch(':id/status')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Ativa/inativa um aluno' })
  updateStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateAlunoStatusDto,
  ): Promise<AlunoResponseDto> {
    return this.service.updateStatus(id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Remove um aluno (soft delete — nunca apagado fisicamente)' })
  async remove(@Param('id', ParseUUIDPipe) id: string): Promise<void> {
    await this.service.remove(id);
  }

  @Post(':id/foto')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Upload da foto do aluno (PNG/JPEG/WebP, até 2MB)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' } } },
  })
  @UseInterceptors(ImageFileInterceptor())
  async uploadFoto(
    @Param('id', ParseUUIDPipe) id: string,
    @UploadedFile() file: Express.Multer.File | undefined,
  ): Promise<AlunoResponseDto> {
    if (!file) {
      throw new BadRequestException('Nenhum arquivo enviado');
    }
    return this.service.uploadFoto(id, file);
  }
}
