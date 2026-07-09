import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Aluno, Arquivo, AuditAction, Prisma } from '@prisma/client';
import { CreateAlunoDto } from './dto/create-aluno.dto';
import { AlunoResponseDto, PaginatedAlunosResponseDto } from './dto/aluno-response.dto';
import { ListAlunosQueryDto } from './dto/list-alunos-query.dto';
import { UpdateAlunoDto } from './dto/update-aluno.dto';
import { UpdateAlunoStatusDto } from './dto/update-aluno-status.dto';
import { TenantContextService } from '../../common/context/tenant-context.service';
import { RequestMetadata } from '../../common/utils/request-metadata';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { FileUploadService, UploadedFileInput } from '../../storage/file-upload.service';

type AlunoComFoto = Aluno & { fotoArquivo: Arquivo | null };

/// CRUD de Aluno — sempre via prisma.forTenant() (Aluno está em
/// TENANT_SCOPED_MODELS desde esta sprint): a extensão do Prisma já
/// garante que nenhuma query aqui alcança um aluno de outra academia,
/// mesmo que este service tivesse um bug. Soft delete filtrado aqui no
/// service (deletedAt: null em toda leitura) — decisão explícita de não
/// empilhar essa responsabilidade na extensão do Prisma (ver plano do
/// Sprint 3).
@Injectable()
export class AlunosService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly fileUploadService: FileUploadService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async create(dto: CreateAlunoDto, meta: RequestMetadata = {}): Promise<AlunoResponseDto> {
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const aluno = await this.criarOuRelancar(() =>
      this.prisma.forTenant().aluno.create({
        // academiaId é injetado em tempo de execução pela extensão de
        // tenant (forTenant()) — o TS não enxerga isso estaticamente, daí
        // o cast: sem ele, exigiria academiaId/academia explícito aqui,
        // que é exatamente o que NUNCA deve vir do chamador.
        data: {
          ...dto,
          dataNascimento: new Date(dto.dataNascimento),
        } as Prisma.AlunoUncheckedCreateInput,
        include: { fotoArquivo: true },
      }),
    );

    await this.auditService.record({
      action: AuditAction.ALUNO_CREATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { alunoId: aluno.id },
      ...meta,
    });

    return this.toResponse(aluno);
  }

  async list(query: ListAlunosQueryDto): Promise<PaginatedAlunosResponseDto> {
    const where: Prisma.AlunoWhereInput = { deletedAt: null };
    if (query.status) {
      where.status = query.status;
    }
    if (query.search) {
      // CPF é armazenado só com dígitos (NormalizeCPF) — sem isso, buscar
      // com a pontuação que o usuário digitou ("111.444.777-35") nunca
      // bateria com o valor salvo.
      const buscaSoDigitos = query.search.replace(/\D/g, '');
      where.OR = [
        { nome: { contains: query.search, mode: 'insensitive' } },
        { cpf: { contains: buscaSoDigitos || query.search } },
        { telefone: { contains: query.search } },
      ];
    }

    const [items, total] = await Promise.all([
      this.prisma.forTenant().aluno.findMany({
        where,
        include: { fotoArquivo: true },
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: { nome: 'asc' },
      }),
      this.prisma.forTenant().aluno.count({ where }),
    ]);

    return {
      items: await Promise.all(items.map((aluno) => this.toResponse(aluno))),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  async findOne(id: string): Promise<AlunoResponseDto> {
    return this.toResponse(await this.findOrThrow(id));
  }

  async update(
    id: string,
    dto: UpdateAlunoDto,
    meta: RequestMetadata = {},
  ): Promise<AlunoResponseDto> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const aluno = await this.criarOuRelancar(() =>
      this.prisma.forTenant().aluno.update({
        where: { id },
        data: {
          ...dto,
          dataNascimento: dto.dataNascimento ? new Date(dto.dataNascimento) : undefined,
        },
        include: { fotoArquivo: true },
      }),
    );

    await this.auditService.record({
      action: AuditAction.ALUNO_UPDATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { alunoId: id, camposAlterados: Object.keys(dto) },
      ...meta,
    });

    return this.toResponse(aluno);
  }

  async updateStatus(
    id: string,
    dto: UpdateAlunoStatusDto,
    meta: RequestMetadata = {},
  ): Promise<AlunoResponseDto> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const aluno = await this.prisma.forTenant().aluno.update({
      where: { id },
      data: { status: dto.status },
      include: { fotoArquivo: true },
    });

    await this.auditService.record({
      action: AuditAction.ALUNO_STATUS_CHANGED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { alunoId: id, statusNovo: dto.status, motivo: dto.motivo },
      ...meta,
    });

    return this.toResponse(aluno);
  }

  async remove(id: string, meta: RequestMetadata = {}): Promise<void> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    await this.prisma.forTenant().aluno.update({ where: { id }, data: { deletedAt: new Date() } });

    await this.auditService.record({
      action: AuditAction.ALUNO_DELETED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { alunoId: id },
      ...meta,
    });
  }

  async uploadFoto(
    id: string,
    file: UploadedFileInput,
    meta: RequestMetadata = {},
  ): Promise<AlunoResponseDto> {
    const aluno = await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const novoArquivo = await this.fileUploadService.uploadAlunoFoto(academiaId, file);

    if (aluno.fotoArquivo) {
      await this.fileUploadService.delete(aluno.fotoArquivo);
    }

    const atualizado = await this.prisma.forTenant().aluno.update({
      where: { id },
      data: { fotoArquivoId: novoArquivo.id },
      include: { fotoArquivo: true },
    });

    await this.auditService.record({
      action: AuditAction.FOTO_UPLOADED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { entidade: 'Aluno', alunoId: id },
      ...meta,
    });

    return this.toResponse(atualizado);
  }

  private async findOrThrow(id: string): Promise<AlunoComFoto> {
    const aluno = await this.prisma.forTenant().aluno.findFirst({
      where: { id, deletedAt: null },
      include: { fotoArquivo: true },
    });
    if (!aluno) {
      throw new NotFoundException('Aluno não encontrado');
    }
    return aluno;
  }

  /// P2002 aqui só pode ser o índice composto (academiaId, cpf) — CPF
  /// duplicado dentro da mesma academia.
  private async criarOuRelancar(operacao: () => Promise<AlunoComFoto>): Promise<AlunoComFoto> {
    try {
      return await operacao();
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('Já existe um aluno com este CPF nesta academia');
      }
      throw error;
    }
  }

  private async toResponse(aluno: AlunoComFoto): Promise<AlunoResponseDto> {
    return {
      id: aluno.id,
      fotoUrl: aluno.fotoArquivo
        ? await this.fileUploadService.resolveUrl(aluno.fotoArquivo.caminho)
        : null,
      nome: aluno.nome,
      cpf: aluno.cpf,
      rg: aluno.rg,
      dataNascimento: aluno.dataNascimento,
      sexo: aluno.sexo,
      telefone: aluno.telefone,
      whatsapp: aluno.whatsapp,
      email: aluno.email,
      endereco: aluno.endereco,
      cidade: aluno.cidade,
      estado: aluno.estado,
      cep: aluno.cep,
      observacoes: aluno.observacoes,
      status: aluno.status,
      createdAt: aluno.createdAt,
    };
  }
}
