import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AuditAction, MatriculaStatus, Prisma } from '@prisma/client';
import { CreateMatriculaDto } from './dto/create-matricula.dto';
import { UpdateMatriculaDto } from './dto/update-matricula.dto';
import { TrancarMatriculaDto } from './dto/trancar-matricula.dto';
import { CancelarMatriculaDto } from './dto/cancelar-matricula.dto';
import { RenovarMatriculaDto } from './dto/renovar-matricula.dto';
import { ListMatriculasQueryDto } from './dto/list-matriculas-query.dto';
import { MatriculaResponseDto, PaginatedMatriculasResponseDto } from './dto/matricula-response.dto';
import { diasEntre, somarDias, somarPeriodicidade } from './matriculas.util';
import { TenantContextService } from '../../common/context/tenant-context.service';
import { RequestMetadata } from '../../common/utils/request-metadata';
import { PrismaService } from '../../prisma/prisma.service';
import { FileUploadService } from '../../storage/file-upload.service';
import { AuditService } from '../audit/audit.service';

/// Projeção de leitura pro frontend renderizar a lista sem N+1 (nome do
/// aluno/plano, foto do aluno) — motivada pela Lista de Matrículas (MS3),
/// não uma mudança de regra de negócio. Usada em toda query que alimenta
/// `toResponse` (create/list/findOrThrow/update/trancar/reativar/cancelar/
/// renovar); o `update` que só encerra a matrícula anterior dentro de
/// `renovar()` não precisa, pois seu retorno é descartado. `fotoArquivo`
/// (não um `fotoUrl` escalar) porque é assim que Aluno guarda a foto — a
/// URL de fato só existe depois de resolvida pelo StorageProvider, mesmo
/// padrão de AlunosService.toResponse.
const alunoResumoSelect = {
  nome: true,
  fotoArquivo: { select: { caminho: true } },
} satisfies Prisma.AlunoSelect;

const matriculaInclude = {
  aluno: { select: alunoResumoSelect },
  plano: { select: { nome: true } },
} satisfies Prisma.MatriculaInclude;

type MatriculaComRelacoes = Prisma.MatriculaGetPayload<{ include: typeof matriculaInclude }>;

/// Núcleo comercial do ERP — liga Aluno a Plano por um período. Ver
/// docs/16-modulo-2-matriculas-analise.md para a análise de domínio
/// completa (cada decisão abaixo referencia o item correspondente lá).
///
/// Diferente de Aluno/Professor/Plano (só ATIVO/INATIVO via um único
/// endpoint de status genérico), o ciclo de vida de Matricula tem
/// transições com payload/efeito colateral próprios (trancar estende
/// dataFim depois; cancelar exige motivo categorizado; renovar cria uma
/// linha nova) — por isso são métodos/endpoints dedicados, não um único
/// `updateStatus` genérico. Mesmo princípio de "operação específica de
/// domínio não entra na camada genérica" já usado no CrudApi<T> do
/// frontend, agora aplicado ao backend.
@Injectable()
export class MatriculasService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
    private readonly fileUploadService: FileUploadService,
  ) {}

  async create(dto: CreateMatriculaDto, meta: RequestMetadata = {}): Promise<MatriculaResponseDto> {
    const academiaId = this.tenantContext.getAcademiaId() as string;
    const userId = this.tenantContext.getUserId() as string;

    const aluno = await this.prisma.forTenant().aluno.findFirst({
      where: { id: dto.alunoId, deletedAt: null },
      include: { fotoArquivo: { select: { caminho: true } } },
    });
    if (!aluno) {
      throw new NotFoundException('Aluno não encontrado');
    }

    const plano = await this.prisma.forTenant().plano.findFirst({
      where: { id: dto.planoId, deletedAt: null },
    });
    if (!plano) {
      throw new NotFoundException('Plano não encontrado');
    }

    await this.garantirSemMatriculaAtiva(dto.alunoId);

    const dataInicio = new Date(dto.dataInicio);
    const dataFimPrevista = somarPeriodicidade(dataInicio, plano.periodicidade);

    const matricula = await this.prisma.forTenant().matricula.create({
      data: {
        alunoId: dto.alunoId,
        planoId: dto.planoId,
        createdByUserId: userId,
        valor: dto.valor ?? plano.valor,
        // getUTCDate(), não getDate(): dataInicio nasce de um IsDateString
        // ("2026-01-10") parseado como meia-noite UTC — em fuso negativo
        // (America/Sao_Paulo, UTC-3) getDate() local voltaria pro dia
        // anterior (9), o dia errado.
        diaVencimento: dto.diaVencimento ?? dataInicio.getUTCDate(),
        dataInicio,
        dataFimPrevista,
        dataFim: dataFimPrevista,
        status: MatriculaStatus.ATIVA,
      } as Prisma.MatriculaUncheckedCreateInput,
    });

    await this.auditService.record({
      action: AuditAction.MATRICULA_CREATED,
      academiaId,
      userId,
      metadata: { matriculaId: matricula.id, alunoId: dto.alunoId, planoId: dto.planoId },
      ...meta,
    });

    // aluno/plano já foram buscados acima pra validar existência — reaproveita
    // em vez de pedir o include numa segunda ida ao banco.
    return this.toResponse({
      ...matricula,
      aluno: { nome: aluno.nome, fotoArquivo: aluno.fotoArquivo },
      plano: { nome: plano.nome },
    });
  }

  async list(query: ListMatriculasQueryDto): Promise<PaginatedMatriculasResponseDto> {
    const where: Prisma.MatriculaWhereInput = { deletedAt: null };
    if (query.alunoId) {
      where.alunoId = query.alunoId;
    }
    if (query.planoId) {
      where.planoId = query.planoId;
    }
    if (query.status) {
      where.status = query.status;
    }
    if (query.search) {
      where.aluno = { nome: { contains: query.search, mode: 'insensitive' } };
    }

    const [items, total] = await Promise.all([
      this.prisma.forTenant().matricula.findMany({
        where,
        include: matriculaInclude,
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.forTenant().matricula.count({ where }),
    ]);

    return {
      items: await Promise.all(items.map((matricula) => this.toResponse(matricula))),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  async findOne(id: string): Promise<MatriculaResponseDto> {
    return this.toResponse(await this.findOrThrow(id));
  }

  async update(
    id: string,
    dto: UpdateMatriculaDto,
    meta: RequestMetadata = {},
  ): Promise<MatriculaResponseDto> {
    const atual = await this.findOrThrow(id);
    this.garantirNaoTerminal(atual);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const matricula = await this.prisma.forTenant().matricula.update({ where: { id }, data: dto });

    await this.auditService.record({
      action: AuditAction.MATRICULA_UPDATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { matriculaId: id, camposAlterados: Object.keys(dto) },
      ...meta,
    });

    // aluno/plano não mudam nesta operação — reaproveita o que `findOrThrow`
    // já trouxe em vez de um include redundante neste `update`.
    return this.toResponse({ ...matricula, aluno: atual.aluno, plano: atual.plano });
  }

  async trancar(
    id: string,
    dto: TrancarMatriculaDto,
    meta: RequestMetadata = {},
  ): Promise<MatriculaResponseDto> {
    const atual = await this.findOrThrow(id);
    if (atual.status !== MatriculaStatus.ATIVA) {
      throw new BadRequestException('Só é possível trancar uma matrícula ATIVA');
    }
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const matricula = await this.prisma.forTenant().matricula.update({
      where: { id },
      data: {
        status: MatriculaStatus.TRANCADA,
        trancadoEm: new Date(),
        trancamentoMotivo: dto.motivo,
      },
    });

    await this.auditService.record({
      action: AuditAction.MATRICULA_STATUS_CHANGED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { matriculaId: id, transicao: 'ATIVA_PARA_TRANCADA', motivo: dto.motivo },
      ...meta,
    });

    return this.toResponse({ ...matricula, aluno: atual.aluno, plano: atual.plano });
  }

  /// Reativar soma os dias em que a matrícula ficou congelada de volta a
  /// `dataFim` — quem tranca 15 dias não perde 15 dias de plano
  /// (docs/16, item 5). `dataFimPrevista` nunca muda.
  async reativar(id: string, meta: RequestMetadata = {}): Promise<MatriculaResponseDto> {
    const atual = await this.findOrThrow(id);
    if (atual.status !== MatriculaStatus.TRANCADA) {
      throw new BadRequestException('Só é possível reativar uma matrícula TRANCADA');
    }
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const diasCongelados = diasEntre(atual.trancadoEm as Date, new Date());
    const novaDataFim = somarDias(atual.dataFim, diasCongelados);

    const matricula = await this.prisma.forTenant().matricula.update({
      where: { id },
      data: {
        status: MatriculaStatus.ATIVA,
        dataFim: novaDataFim,
        trancadoEm: null,
        trancamentoMotivo: null,
      },
    });

    await this.auditService.record({
      action: AuditAction.MATRICULA_STATUS_CHANGED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { matriculaId: id, transicao: 'TRANCADA_PARA_ATIVA', diasCongelados },
      ...meta,
    });

    return this.toResponse({ ...matricula, aluno: atual.aluno, plano: atual.plano });
  }

  async cancelar(
    id: string,
    dto: CancelarMatriculaDto,
    meta: RequestMetadata = {},
  ): Promise<MatriculaResponseDto> {
    const atual = await this.findOrThrow(id);
    if (atual.status !== MatriculaStatus.ATIVA && atual.status !== MatriculaStatus.TRANCADA) {
      throw new BadRequestException('Só é possível cancelar uma matrícula ATIVA ou TRANCADA');
    }
    const academiaId = this.tenantContext.getAcademiaId() as string;
    const statusAnterior = atual.status;

    const matricula = await this.prisma.forTenant().matricula.update({
      where: { id },
      data: {
        status: MatriculaStatus.CANCELADA,
        motivoCancelamento: dto.motivoCancelamento,
        motivoCancelamentoDetalhe: dto.motivoCancelamentoDetalhe,
      },
    });

    await this.auditService.record({
      action: AuditAction.MATRICULA_STATUS_CHANGED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: {
        matriculaId: id,
        transicao: `${statusAnterior}_PARA_CANCELADA`,
        motivoCancelamento: dto.motivoCancelamento,
      },
      ...meta,
    });

    return this.toResponse({ ...matricula, aluno: atual.aluno, plano: atual.plano });
  }

  /// Upgrade/downgrade/renovação são sempre a mesma operação: encerrar a
  /// atual (ENCERRADA) e criar uma nova, ligada pela anterior via
  /// `matriculaAnteriorId` (docs/16, itens 3 e 12). `planoId` nunca muda —
  /// a nova matrícula herda o mesmo plano da anterior; trocar de plano de
  /// verdade é cancelar esta e criar uma matrícula nova para outro plano
  /// via `create()`, não via `renovar()`.
  async renovar(
    id: string,
    dto: RenovarMatriculaDto,
    meta: RequestMetadata = {},
  ): Promise<MatriculaResponseDto> {
    const atual = await this.findOrThrow(id);
    if (atual.status !== MatriculaStatus.ATIVA) {
      throw new BadRequestException('Só é possível renovar uma matrícula ATIVA');
    }
    const academiaId = this.tenantContext.getAcademiaId() as string;
    const userId = this.tenantContext.getUserId() as string;

    const plano = await this.prisma.forTenant().plano.findFirst({
      where: { id: atual.planoId, deletedAt: null },
    });
    if (!plano) {
      throw new NotFoundException('Plano não encontrado');
    }

    const dataInicio = dto.dataInicio ? new Date(dto.dataInicio) : somarDias(atual.dataFim, 1);
    const dataFimPrevista = somarPeriodicidade(dataInicio, plano.periodicidade);

    // Transação com o client base (não forTenant()) — mesmo padrão já
    // usado em AcademiaProvisioningService/AuthService: dentro de uma
    // transação interativa, academiaId é setado manualmente em cada
    // operação, e o where inclui academiaId explícito (a extensão de
    // tenant não intercepta `tx`).
    const nova = await this.prisma.$transaction(async (tx) => {
      await tx.matricula.update({
        where: { id, academiaId },
        data: { status: MatriculaStatus.ENCERRADA },
      });

      return tx.matricula.create({
        data: {
          academiaId,
          alunoId: atual.alunoId,
          planoId: atual.planoId,
          createdByUserId: userId,
          valor: dto.valor ?? Number(atual.valor),
          diaVencimento: dto.diaVencimento ?? atual.diaVencimento,
          dataInicio,
          dataFimPrevista,
          dataFim: dataFimPrevista,
          status: MatriculaStatus.ATIVA,
          matriculaAnteriorId: atual.id,
        },
      });
    });

    await this.auditService.record({
      action: AuditAction.MATRICULA_STATUS_CHANGED,
      academiaId,
      userId,
      metadata: {
        matriculaId: id,
        transicao: 'ATIVA_PARA_ENCERRADA_RENOVACAO',
        novaMatriculaId: nova.id,
      },
      ...meta,
    });
    await this.auditService.record({
      action: AuditAction.MATRICULA_CREATED,
      academiaId,
      userId,
      metadata: { matriculaId: nova.id, renovacaoDe: id },
      ...meta,
    });

    return this.toResponse({ ...nova, aluno: atual.aluno, plano: { nome: plano.nome } });
  }

  /// Reservado a correção de erro de cadastro — cancelamento de verdade é
  /// `cancelar()` (status = CANCELADA, preserva histórico de churn), não
  /// isto (docs/16, item 8).
  async remove(id: string, meta: RequestMetadata = {}): Promise<void> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    await this.prisma
      .forTenant()
      .matricula.update({ where: { id }, data: { deletedAt: new Date() } });

    await this.auditService.record({
      action: AuditAction.MATRICULA_DELETED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { matriculaId: id },
      ...meta,
    });
  }

  private async garantirSemMatriculaAtiva(alunoId: string): Promise<void> {
    const matriculaAtiva = await this.prisma.forTenant().matricula.findFirst({
      where: { alunoId, status: MatriculaStatus.ATIVA, deletedAt: null },
    });
    if (matriculaAtiva) {
      throw new ConflictException(
        'Aluno já possui uma matrícula ativa — cancele ou renove antes de criar uma nova',
      );
    }
  }

  private garantirNaoTerminal(matricula: MatriculaComRelacoes): void {
    if (
      matricula.status === MatriculaStatus.CANCELADA ||
      matricula.status === MatriculaStatus.ENCERRADA
    ) {
      throw new BadRequestException(
        'Matrícula em estado terminal (CANCELADA/ENCERRADA) não pode ser editada',
      );
    }
  }

  private async findOrThrow(id: string): Promise<MatriculaComRelacoes> {
    const matricula = await this.prisma
      .forTenant()
      .matricula.findFirst({ where: { id, deletedAt: null }, include: matriculaInclude });
    if (!matricula) {
      throw new NotFoundException('Matrícula não encontrada');
    }
    return matricula;
  }

  private async toResponse(matricula: MatriculaComRelacoes): Promise<MatriculaResponseDto> {
    return {
      id: matricula.id,
      alunoId: matricula.alunoId,
      alunoNome: matricula.aluno.nome,
      alunoFotoUrl: matricula.aluno.fotoArquivo
        ? await this.fileUploadService.resolveUrl(matricula.aluno.fotoArquivo.caminho)
        : null,
      planoId: matricula.planoId,
      planoNome: matricula.plano.nome,
      createdByUserId: matricula.createdByUserId,
      valor: Number(matricula.valor),
      diaVencimento: matricula.diaVencimento,
      dataInicio: matricula.dataInicio,
      dataFimPrevista: matricula.dataFimPrevista,
      dataFim: matricula.dataFim,
      status: matricula.status,
      trancadoEm: matricula.trancadoEm,
      trancamentoMotivo: matricula.trancamentoMotivo,
      motivoCancelamento: matricula.motivoCancelamento,
      motivoCancelamentoDetalhe: matricula.motivoCancelamentoDetalhe,
      matriculaAnteriorId: matricula.matriculaAnteriorId,
      createdAt: matricula.createdAt,
    };
  }
}
