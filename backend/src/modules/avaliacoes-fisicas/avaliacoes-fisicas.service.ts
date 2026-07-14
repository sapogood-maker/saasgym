import { Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction, Prisma } from '@prisma/client';
import { CreateAvaliacaoFisicaDto } from './dto/create-avaliacao-fisica.dto';
import { ListAvaliacoesFisicasQueryDto } from './dto/list-avaliacoes-fisicas-query.dto';
import {
  AvaliacaoFisicaResponseDto,
  PaginatedAvaliacoesFisicasResponseDto,
} from './dto/avaliacao-fisica-response.dto';
import { calcularImc } from './avaliacoes-fisicas.util';
import { TenantContextService } from '../../common/context/tenant-context.service';
import { RequestMetadata } from '../../common/utils/request-metadata';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';

/// Módulo 5 (Avaliação Física) — **invariantes explícitas antes de
/// qualquer código (docs/20)**:
///
/// 1. Fato histórico imutável — nunca há `update`. Corrigir um erro de
///    cadastro é soft delete + nova avaliação.
/// 2. IMC nunca é armazenado — sempre calculado (peso / altura²) na
///    resposta.
/// 3. Sem vínculo com `Professor` — autoria via `createdByUserId`, mesmo
///    campo de auditoria de todo o resto do produto.
@Injectable()
export class AvaliacoesFisicasService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async create(
    alunoId: string,
    dto: CreateAvaliacaoFisicaDto,
    meta: RequestMetadata = {},
  ): Promise<AvaliacaoFisicaResponseDto> {
    await this.garantirAlunoExiste(alunoId);

    const academiaId = this.tenantContext.getAcademiaId() as string;
    const userId = this.tenantContext.getUserId() as string;

    const avaliacao = await this.prisma.forTenant().avaliacaoFisica.create({
      data: {
        alunoId,
        data: new Date(dto.data),
        peso: dto.peso,
        altura: dto.altura,
        observacoes: dto.observacoes,
        createdByUserId: userId,
      } as Prisma.AvaliacaoFisicaUncheckedCreateInput,
    });

    await this.auditService.record({
      action: AuditAction.AVALIACAO_FISICA_CREATED,
      academiaId,
      userId,
      metadata: { avaliacaoFisicaId: avaliacao.id, alunoId, peso: dto.peso, altura: dto.altura },
      ...meta,
    });

    return this.toResponse(avaliacao);
  }

  async list(
    alunoId: string,
    query: ListAvaliacoesFisicasQueryDto,
  ): Promise<PaginatedAvaliacoesFisicasResponseDto> {
    await this.garantirAlunoExiste(alunoId);

    const where: Prisma.AvaliacaoFisicaWhereInput = { alunoId, deletedAt: null };

    const [items, total] = await Promise.all([
      this.prisma.forTenant().avaliacaoFisica.findMany({
        where,
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: { data: 'desc' },
      }),
      this.prisma.forTenant().avaliacaoFisica.count({ where }),
    ]);

    return {
      items: items.map((avaliacao) => this.toResponse(avaliacao)),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  /// Reservado a correção de erro de cadastro — nunca "editar" (invariante
  /// 1). Sem bloqueio adicional (diferente de `Mensalidade.remove`, que
  /// bloqueia se `status = PAGA`): uma avaliação não tem nenhum outro
  /// registro dependente dela.
  async remove(alunoId: string, id: string, meta: RequestMetadata = {}): Promise<void> {
    const atual = await this.findOrThrow(alunoId, id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    await this.prisma
      .forTenant()
      .avaliacaoFisica.update({ where: { id: atual.id }, data: { deletedAt: new Date() } });

    await this.auditService.record({
      action: AuditAction.AVALIACAO_FISICA_DELETED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { avaliacaoFisicaId: id, alunoId },
      ...meta,
    });
  }

  private async garantirAlunoExiste(alunoId: string): Promise<void> {
    const aluno = await this.prisma.forTenant().aluno.findFirst({ where: { id: alunoId, deletedAt: null } });
    if (!aluno) {
      throw new NotFoundException('Aluno não encontrado');
    }
  }

  private async findOrThrow(
    alunoId: string,
    id: string,
  ): Promise<Prisma.AvaliacaoFisicaGetPayload<Record<string, never>>> {
    const avaliacao = await this.prisma
      .forTenant()
      .avaliacaoFisica.findFirst({ where: { id, alunoId, deletedAt: null } });
    if (!avaliacao) {
      throw new NotFoundException('Avaliação física não encontrada');
    }
    return avaliacao;
  }

  private toResponse(
    avaliacao: Prisma.AvaliacaoFisicaGetPayload<Record<string, never>>,
  ): AvaliacaoFisicaResponseDto {
    const peso = Number(avaliacao.peso);
    const altura = Number(avaliacao.altura);

    return {
      id: avaliacao.id,
      alunoId: avaliacao.alunoId,
      data: avaliacao.data,
      peso,
      altura,
      imc: calcularImc(peso, altura),
      observacoes: avaliacao.observacoes,
      createdAt: avaliacao.createdAt,
    };
  }
}
