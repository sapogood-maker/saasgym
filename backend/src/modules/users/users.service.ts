import { Injectable } from '@nestjs/common';
import { Arquivo, AuditAction, User } from '@prisma/client';
import { UpdateUserProfileDto } from './dto/update-user-profile.dto';
import { UserProfileResponseDto } from './dto/user-profile-response.dto';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { FileUploadService, UploadedFileInput } from '../../storage/file-upload.service';

type UserComFoto = User & { fotoArquivo: Arquivo | null };

/// Perfil do próprio usuário logado — sempre this.prisma "cru" (nunca
/// forTenant()): a busca é por userId exato vindo do JWT já verificado,
/// não uma listagem tenant-scoped. Mesmo padrão de AuthService.me().
/// Precisa funcionar para SYSTEM_ADMIN também, por isso nenhum
/// AcademiaGuard aqui (mesma razão de /auth/me).
@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly fileUploadService: FileUploadService,
    private readonly auditService: AuditService,
  ) {}

  async me(userId: string): Promise<UserProfileResponseDto> {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      include: { fotoArquivo: true },
    });
    return this.toResponse(user);
  }

  async updateMe(userId: string, dto: UpdateUserProfileDto): Promise<UserProfileResponseDto> {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { nome: dto.nome },
      include: { fotoArquivo: true },
    });

    await this.auditService.record({
      action: AuditAction.USER_PROFILE_UPDATED,
      userId,
      academiaId: user.academiaId,
      metadata: { camposAlterados: Object.keys(dto) },
    });

    return this.toResponse(user);
  }

  async uploadFoto(userId: string, file: UploadedFileInput): Promise<UserProfileResponseDto> {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      include: { fotoArquivo: true },
    });

    const novoArquivo = await this.fileUploadService.uploadUserAvatar(user.academiaId, file);

    if (user.fotoArquivo) {
      await this.fileUploadService.delete(user.fotoArquivo);
    }

    const atualizado = await this.prisma.user.update({
      where: { id: userId },
      data: { fotoArquivoId: novoArquivo.id },
      include: { fotoArquivo: true },
    });

    await this.auditService.record({
      action: AuditAction.FOTO_UPLOADED,
      userId,
      academiaId: user.academiaId,
      metadata: { entidade: 'User' },
    });

    return this.toResponse(atualizado);
  }

  private async toResponse(user: UserComFoto): Promise<UserProfileResponseDto> {
    return {
      id: user.id,
      nome: user.nome,
      email: user.email,
      role: user.role,
      academiaId: user.academiaId,
      fotoUrl: user.fotoArquivo
        ? await this.fileUploadService.resolveUrl(user.fotoArquivo.caminho)
        : null,
    };
  }
}
