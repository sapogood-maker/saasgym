import {
  Body,
  Controller,
  Get,
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
import { SolicitacoesReposicaoService } from './solicitacoes-reposicao.service';
import { CreateSolicitacaoReposicaoDto } from './dto/create-solicitacao-reposicao.dto';
import { AprovarSolicitacaoReposicaoDto } from './dto/aprovar-solicitacao-reposicao.dto';
import { RejeitarSolicitacaoReposicaoDto } from './dto/rejeitar-solicitacao-reposicao.dto';
import { ListSolicitacoesReposicaoQueryDto } from './dto/list-solicitacoes-reposicao-query.dto';
import {
  PaginatedSolicitacoesReposicaoResponseDto,
  SolicitacaoReposicaoResponseDto,
} from './dto/solicitacao-reposicao-response.dto';
import { AcademiaGuard } from '../../../common/guards/academia.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { Roles } from '../../../common/decorators/roles.decorator';
import { requestMetadata } from '../../../common/utils/request-metadata';

/// Sprint 6 (Agenda Avançada) — controller de topo (não aninhado em Turma
/// nem Aluno): a gestão de solicitações cruza alunos/turmas, mesmo
/// critério já usado pra `AulasCalendarioController` (docs/21, decisão 11).
@ApiTags('agenda/solicitacoes-reposicao')
@ApiBearerAuth()
@UseGuards(AcademiaGuard, RolesGuard)
@Controller('agenda/solicitacoes-reposicao')
export class SolicitacoesReposicaoController {
  constructor(private readonly service: SolicitacoesReposicaoService) {}

  @Post()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Registra uma solicitação de reposição para uma aula perdida (falta ou cancelada)' })
  create(
    @Body() dto: CreateSolicitacaoReposicaoDto,
    @Req() req: Request,
  ): Promise<SolicitacaoReposicaoResponseDto> {
    return this.service.criar(dto, requestMetadata(req));
  }

  @Get()
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Lista solicitações de reposição, paginado, com filtro por status/aluno' })
  list(
    @Query() query: ListSolicitacoesReposicaoQueryDto,
  ): Promise<PaginatedSolicitacoesReposicaoResponseDto> {
    return this.service.list(query);
  }

  @Patch(':id/aprovar')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({
    summary: 'Aprova a solicitação, escolhendo a aula de destino — cria o AulaAluno(tipo=REPOSICAO)',
  })
  aprovar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AprovarSolicitacaoReposicaoDto,
    @Req() req: Request,
  ): Promise<SolicitacaoReposicaoResponseDto> {
    return this.service.aprovar(id, dto, requestMetadata(req));
  }

  @Patch(':id/rejeitar')
  @Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)
  @ApiOperation({ summary: 'Rejeita a solicitação, com motivo opcional' })
  rejeitar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RejeitarSolicitacaoReposicaoDto,
    @Req() req: Request,
  ): Promise<SolicitacaoReposicaoResponseDto> {
    return this.service.rejeitar(id, dto, requestMetadata(req));
  }
}
