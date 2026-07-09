import { Injectable, NotFoundException } from '@nestjs/common';
import { AcademiaConfiguracao, Arquivo, AuditAction, Prisma } from '@prisma/client';
import { AcademiaConfiguracaoResponseDto } from './dto/academia-configuracao-response.dto';
import { UpdateAcademiaConfiguracaoDto } from './dto/update-academia-configuracao.dto';
import { TenantContextService } from '../../../common/context/tenant-context.service';
import { PrismaService } from '../../../prisma/prisma.service';
import { FileUploadService, UploadedFileInput } from '../../../storage/file-upload.service';
import { AuditService } from '../../audit/audit.service';

type ConfiguracaoComLogo = AcademiaConfiguracao & { logoArquivo: Arquivo | null };

/// Branding de cada academia — separado do CRUD principal (AdminAcademiaService)
/// porque é um sub-recurso conceitualmente distinto (apresentação, não
/// identidade legal do tenant). Toda academia tem uma linha aqui desde a
/// criação (AcademiaProvisioningService); se não tiver, é um problema de
/// integridade de dados, não um caso normal a tratar silenciosamente.
@Injectable()
export class AdminAcademiaConfiguracaoService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly fileUploadService: FileUploadService,
    private readonly auditService: AuditService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async get(academiaId: string): Promise<AcademiaConfiguracaoResponseDto> {
    const configuracao = await this.findOrThrow(academiaId);
    return this.toResponse(configuracao);
  }

  async update(
    academiaId: string,
    dto: UpdateAcademiaConfiguracaoDto,
  ): Promise<AcademiaConfiguracaoResponseDto> {
    await this.findOrThrow(academiaId);

    const atualizada = await this.prisma.academiaConfiguracao.update({
      where: { academiaId },
      data: {
        ...dto,
        temaCores: dto.temaCores as Prisma.InputJsonValue | undefined,
        horarioFuncionamento: dto.horarioFuncionamento as Prisma.InputJsonValue | undefined,
      },
      include: { logoArquivo: true },
    });

    await this.auditService.record({
      action: AuditAction.ACADEMIA_CONFIGURACAO_UPDATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { camposAlterados: Object.keys(dto) },
    });

    return this.toResponse(atualizada);
  }

  /// Substitui o logo: sobe o novo antes de apagar o antigo (se o upload
  /// falhar, o logo anterior continua servindo — nunca fica um período sem
  /// logo nenhum por causa de uma falha no meio do caminho).
  async updateLogo(
    academiaId: string,
    file: UploadedFileInput,
  ): Promise<AcademiaConfiguracaoResponseDto> {
    const configuracao = await this.findOrThrow(academiaId);

    const novoArquivo = await this.fileUploadService.uploadAcademiaLogo(academiaId, file);

    if (configuracao.logoArquivo) {
      await this.fileUploadService.delete(configuracao.logoArquivo);
    }

    const atualizada = await this.prisma.academiaConfiguracao.update({
      where: { academiaId },
      data: { logoArquivoId: novoArquivo.id },
      include: { logoArquivo: true },
    });

    await this.auditService.record({
      action: AuditAction.ACADEMIA_CONFIGURACAO_UPDATED,
      academiaId,
      userId: this.tenantContext.getUserId(),
      metadata: { camposAlterados: ['logo'] },
    });

    return this.toResponse(atualizada);
  }

  private async findOrThrow(academiaId: string): Promise<ConfiguracaoComLogo> {
    const configuracao = await this.prisma.academiaConfiguracao.findUnique({
      where: { academiaId },
      include: { logoArquivo: true },
    });
    if (!configuracao) {
      throw new NotFoundException('Configuração da academia não encontrada');
    }
    return configuracao;
  }

  private async toResponse(
    configuracao: ConfiguracaoComLogo,
  ): Promise<AcademiaConfiguracaoResponseDto> {
    return {
      academiaId: configuracao.academiaId,
      logoUrl: configuracao.logoArquivo
        ? await this.fileUploadService.resolveUrl(configuracao.logoArquivo.caminho)
        : null,
      temaCores: configuracao.temaCores as Record<string, unknown> | null,
      whatsapp: configuracao.whatsapp,
      instagram: configuracao.instagram,
      facebook: configuracao.facebook,
      pix: configuracao.pix,
      horarioFuncionamento: configuracao.horarioFuncionamento as Record<string, unknown> | null,
    };
  }
}
