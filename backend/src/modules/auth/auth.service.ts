import { Injectable, UnauthorizedException } from '@nestjs/common';
import { AuditAction, User, UserStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { AuditService } from '../audit/audit.service';
import { isAcademiaStatusBlocking } from '../../common/academia/academia-status.util';
import { PrismaService } from '../../prisma/prisma.service';
import { TokenService } from './tokens/token.service';
import { UserProfileDto } from './dto/user-profile.dto';

export interface RequestMetadata {
  ipAddress?: string;
  userAgent?: string;
}

export interface LoginResult {
  accessToken: string;
  refreshToken: string;
  refreshTokenExpiresAt: Date;
  user: UserProfileDto;
}

export interface RefreshResult {
  accessToken: string;
  refreshToken: string;
  refreshTokenExpiresAt: Date;
}

// Hash "de mentira" usado quando o e-mail não existe, para que o tempo de
// resposta de um login com e-mail inexistente seja parecido com o de um
// login com senha errada — evita descobrir e-mails cadastrados por timing.
const DUMMY_PASSWORD_HASH = bcrypt.hashSync('dummy-password-for-timing-safety', 10);

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokenService: TokenService,
    private readonly auditService: AuditService,
  ) {}

  async login(email: string, password: string, meta: RequestMetadata): Promise<LoginResult> {
    const user = await this.prisma.user.findUnique({
      where: { email },
      include: { academia: true },
    });
    const passwordMatches = await bcrypt.compare(password, user?.senhaHash ?? DUMMY_PASSWORD_HASH);

    if (!user || user.status !== UserStatus.ATIVO || !passwordMatches) {
      await this.auditService.record({
        action: AuditAction.LOGIN_FAILURE,
        identifier: email,
        userId: user?.id,
        academiaId: user?.academiaId,
        ipAddress: meta.ipAddress,
        userAgent: meta.userAgent,
      });
      throw new UnauthorizedException('Credenciais inválidas');
    }

    // Credenciais corretas, mas a academia está suspensa/bloqueada/
    // cancelada — só chega aqui depois do bcrypt.compare acima, então não
    // introduz um atalho de timing distinguível de "senha errada".
    if (user.academia && isAcademiaStatusBlocking(user.academia.status)) {
      await this.auditService.record({
        action: AuditAction.LOGIN_FAILURE,
        identifier: email,
        userId: user.id,
        academiaId: user.academiaId,
        ipAddress: meta.ipAddress,
        userAgent: meta.userAgent,
        metadata: { motivo: 'academia_status_bloqueante', status: user.academia.status },
      });
      throw new UnauthorizedException(
        'Esta academia está com o acesso suspenso. Entre em contato com o suporte.',
      );
    }

    const accessToken = await this.tokenService.signAccessToken({
      sub: user.id,
      academiaId: user.academiaId,
      role: user.role,
    });
    const refresh = this.tokenService.issueRefreshToken();

    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: refresh.hash,
        expiresAt: refresh.expiresAt,
        ipAddress: meta.ipAddress,
        userAgent: meta.userAgent,
      },
    });
    await this.prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });

    await this.auditService.record({
      action: AuditAction.LOGIN_SUCCESS,
      identifier: email,
      userId: user.id,
      academiaId: user.academiaId,
      ipAddress: meta.ipAddress,
      userAgent: meta.userAgent,
    });

    return {
      accessToken,
      refreshToken: refresh.raw,
      refreshTokenExpiresAt: refresh.expiresAt,
      user: this.toProfile(user),
    };
  }

  async me(userId: string): Promise<UserProfileDto> {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    return this.toProfile(user);
  }

  /// Rotaciona o refresh token: o token apresentado é revogado e um novo é
  /// emitido. Reapresentar um token já revogado é tratado como possível
  /// roubo — revoga toda a família de sessões do usuário imediatamente.
  async refresh(rawToken: string, meta: RequestMetadata): Promise<RefreshResult> {
    const tokenHash = this.tokenService.hashRefreshToken(rawToken);
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: { include: { academia: true } } },
    });

    if (!stored) {
      throw new UnauthorizedException('Refresh token inválido');
    }

    if (stored.revokedAt) {
      await this.revokeAllUserTokens(stored.userId, stored.user.academiaId);
      await this.auditService.record({
        action: AuditAction.REFRESH_TOKEN_REUSE_DETECTED,
        userId: stored.userId,
        academiaId: stored.user.academiaId,
        ipAddress: meta.ipAddress,
        userAgent: meta.userAgent,
      });
      throw new UnauthorizedException('Refresh token inválido');
    }

    if (stored.expiresAt < new Date() || stored.user.status !== UserStatus.ATIVO) {
      throw new UnauthorizedException('Refresh token inválido');
    }

    if (stored.user.academia && isAcademiaStatusBlocking(stored.user.academia.status)) {
      throw new UnauthorizedException('Refresh token inválido');
    }

    const newRefresh = this.tokenService.issueRefreshToken();

    await this.prisma.$transaction(async (tx) => {
      const created = await tx.refreshToken.create({
        data: {
          userId: stored.userId,
          tokenHash: newRefresh.hash,
          expiresAt: newRefresh.expiresAt,
          ipAddress: meta.ipAddress,
          userAgent: meta.userAgent,
        },
      });
      await tx.refreshToken.update({
        where: { id: stored.id },
        data: { revokedAt: new Date(), replacedBy: created.id, lastUsedAt: new Date() },
      });
    });

    const accessToken = await this.tokenService.signAccessToken({
      sub: stored.userId,
      academiaId: stored.user.academiaId,
      role: stored.user.role,
    });

    await this.auditService.record({
      action: AuditAction.REFRESH_TOKEN_USED,
      userId: stored.userId,
      academiaId: stored.user.academiaId,
      ipAddress: meta.ipAddress,
      userAgent: meta.userAgent,
    });

    return {
      accessToken,
      refreshToken: newRefresh.raw,
      refreshTokenExpiresAt: newRefresh.expiresAt,
    };
  }

  /// Troca a senha e revoga todas as sessões do usuário — inclusive a atual,
  /// que também usava a senha antiga como parte da cadeia de confiança;
  /// força um novo login em todos os dispositivos.
  async changePassword(
    userId: string,
    academiaId: string | null,
    currentPassword: string,
    newPassword: string,
    meta: RequestMetadata,
  ): Promise<void> {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });

    const matches = await bcrypt.compare(currentPassword, user.senhaHash);
    if (!matches) {
      throw new UnauthorizedException('Senha atual incorreta');
    }

    const newHash = await bcrypt.hash(newPassword, 10);

    await this.prisma.user.update({
      where: { id: userId },
      data: { senhaHash: newHash, passwordChangedAt: new Date() },
    });

    await this.revokeAllUserTokens(userId, academiaId);

    await this.auditService.record({
      action: AuditAction.PASSWORD_CHANGED,
      userId,
      academiaId,
      ipAddress: meta.ipAddress,
      userAgent: meta.userAgent,
    });
  }

  /// Idempotente: se o token já não existir ou já estiver revogado, não faz
  /// nada (chamar logout duas vezes não é um erro).
  async logout(
    userId: string,
    academiaId: string | null,
    rawToken: string | undefined,
    meta: RequestMetadata,
  ): Promise<void> {
    if (!rawToken) {
      return;
    }

    const tokenHash = this.tokenService.hashRefreshToken(rawToken);
    const stored = await this.prisma.refreshToken.findUnique({ where: { tokenHash } });

    if (!stored || stored.revokedAt) {
      return;
    }

    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revokedAt: new Date() },
    });

    await this.auditService.record({
      action: AuditAction.LOGOUT,
      userId,
      academiaId,
      ipAddress: meta.ipAddress,
      userAgent: meta.userAgent,
    });
  }

  private async revokeAllUserTokens(userId: string, academiaId: string | null): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });

    await this.auditService.record({ action: AuditAction.SESSION_REVOKED, userId, academiaId });
  }

  private toProfile(user: User): UserProfileDto {
    return {
      id: user.id,
      nome: user.nome,
      email: user.email,
      role: user.role,
      academiaId: user.academiaId,
    };
  }
}
