import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Arquivo, AuditAction, Prisma, Professor } from '@prisma/client';
import { CreateProfessorDto } from './dto/create-professor.dto';
import { ListProfessoresQueryDto } from './dto/list-professores-query.dto';
import {
  PaginatedProfessoresResponseDto,
  ProfessorResponseDto,
} from './dto/professor-response.dto';
import { UpdateProfessorDto } from './dto/update-professor.dto';
import { UpdateProfessorStatusDto } from './dto/update-professor-status.dto';
import { TenantContextService } from '../../common/context/tenant-context.service';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { FileUploadService, UploadedFileInput } from '../../storage/file-upload.service';

type ProfessorComFoto = Professor & { fotoArquivo: Arquivo | null };

/// CRUD de Professor — mesmo padrão de AlunosService (ver comentário lá):
/// prisma.forTenant() (Professor em TENANT_SCOPED_MODELS), soft delete
/// filtrado aqui no service, não na extensão do Prisma. Cadastro
/// administrativo apenas — não cria conta de login (ver docs).
@Injectable()
export class ProfessoresService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly fileUploadService: FileUploadService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async create(dto: CreateProfessorDto): Promise<ProfessorResponseDto> {
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const professor = await this.criarOuRelancar(() =>
      this.prisma.forTenant().professor.create({
        data: { ...dto } as Prisma.ProfessorUncheckedCreateInput,
        include: { fotoArquivo: true },
      }),
    );

    await this.auditService.record({
      action: AuditAction.PROFESSOR_CREATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { professorId: professor.id },
    });

    return this.toResponse(professor);
  }

  async list(query: ListProfessoresQueryDto): Promise<PaginatedProfessoresResponseDto> {
    const where: Prisma.ProfessorWhereInput = { deletedAt: null };
    if (query.status) {
      where.status = query.status;
    }
    if (query.search) {
      where.OR = [
        { nome: { contains: query.search, mode: 'insensitive' } },
        { cpf: { contains: query.search } },
        { telefone: { contains: query.search } },
      ];
    }

    const [items, total] = await Promise.all([
      this.prisma.forTenant().professor.findMany({
        where,
        include: { fotoArquivo: true },
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: { nome: 'asc' },
      }),
      this.prisma.forTenant().professor.count({ where }),
    ]);

    return {
      items: await Promise.all(items.map((professor) => this.toResponse(professor))),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  async findOne(id: string): Promise<ProfessorResponseDto> {
    return this.toResponse(await this.findOrThrow(id));
  }

  async update(id: string, dto: UpdateProfessorDto): Promise<ProfessorResponseDto> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const professor = await this.criarOuRelancar(() =>
      this.prisma.forTenant().professor.update({
        where: { id },
        data: { ...dto },
        include: { fotoArquivo: true },
      }),
    );

    await this.auditService.record({
      action: AuditAction.PROFESSOR_UPDATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { professorId: id, camposAlterados: Object.keys(dto) },
    });

    return this.toResponse(professor);
  }

  async updateStatus(id: string, dto: UpdateProfessorStatusDto): Promise<ProfessorResponseDto> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const professor = await this.prisma.forTenant().professor.update({
      where: { id },
      data: { status: dto.status },
      include: { fotoArquivo: true },
    });

    await this.auditService.record({
      action: AuditAction.PROFESSOR_STATUS_CHANGED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { professorId: id, statusNovo: dto.status, motivo: dto.motivo },
    });

    return this.toResponse(professor);
  }

  async remove(id: string): Promise<void> {
    await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    await this.prisma.forTenant().professor.update({
      where: { id },
      data: { deletedAt: new Date() },
    });

    await this.auditService.record({
      action: AuditAction.PROFESSOR_DELETED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { professorId: id },
    });
  }

  async uploadFoto(id: string, file: UploadedFileInput): Promise<ProfessorResponseDto> {
    const professor = await this.findOrThrow(id);
    const academiaId = this.tenantContext.getAcademiaId() as string;

    const novoArquivo = await this.fileUploadService.uploadProfessorFoto(academiaId, file);

    if (professor.fotoArquivo) {
      await this.fileUploadService.delete(professor.fotoArquivo);
    }

    const atualizado = await this.prisma.forTenant().professor.update({
      where: { id },
      data: { fotoArquivoId: novoArquivo.id },
      include: { fotoArquivo: true },
    });

    await this.auditService.record({
      action: AuditAction.FOTO_UPLOADED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { entidade: 'Professor', professorId: id },
    });

    return this.toResponse(atualizado);
  }

  private async findOrThrow(id: string): Promise<ProfessorComFoto> {
    const professor = await this.prisma.forTenant().professor.findFirst({
      where: { id, deletedAt: null },
      include: { fotoArquivo: true },
    });
    if (!professor) {
      throw new NotFoundException('Professor não encontrado');
    }
    return professor;
  }

  /// P2002 aqui só pode ser o índice composto (academiaId, cpf).
  private async criarOuRelancar(
    operacao: () => Promise<ProfessorComFoto>,
  ): Promise<ProfessorComFoto> {
    try {
      return await operacao();
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('Já existe um professor com este CPF nesta academia');
      }
      throw error;
    }
  }

  private async toResponse(professor: ProfessorComFoto): Promise<ProfessorResponseDto> {
    return {
      id: professor.id,
      fotoUrl: professor.fotoArquivo
        ? await this.fileUploadService.resolveUrl(professor.fotoArquivo.caminho)
        : null,
      nome: professor.nome,
      cpf: professor.cpf,
      telefone: professor.telefone,
      email: professor.email,
      especialidade: professor.especialidade,
      observacoes: professor.observacoes,
      status: professor.status,
      createdAt: professor.createdAt,
    };
  }
}
