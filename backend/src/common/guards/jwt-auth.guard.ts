import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@prisma/client';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { AuthenticatedUser } from '../types/authenticated-user.interface';

interface AccessTokenPayload {
  sub: string;
  academiaId: string | null;
  role: Role;
}

/// Verifica o access token (via @nestjs/jwt, sem Passport — ver
/// docs/10-auth.md) e popula request.user. Respeita @Public() para
/// login/refresh e para o próprio health-check.
///
/// Não popula o TenantContext aqui: um guard `async` que faz `await` antes
/// de chamar `AsyncLocalStorage.enterWith()` não propagia o valor de volta
/// para quem o chamou (comportamento documentado do Node — verificado com um
/// teste dedicado). Quem popula o TenantContext de forma correta é o
/// `TenantContextInterceptor`, que envolve a própria subscription do
/// handler com `AsyncLocalStorage.run()`.
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const token = this.extractToken(request);

    if (!token) {
      throw new UnauthorizedException('Token de acesso ausente');
    }

    let payload: AccessTokenPayload;
    try {
      payload = await this.jwtService.verifyAsync<AccessTokenPayload>(token, {
        secret: this.configService.get<string>('JWT_ACCESS_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Token de acesso inválido ou expirado');
    }

    const user: AuthenticatedUser = {
      userId: payload.sub,
      academiaId: payload.academiaId,
      role: payload.role,
    };

    request.user = user;

    return true;
  }

  private extractToken(request: {
    headers: Record<string, string | string[] | undefined>;
  }): string | undefined {
    const authHeader = request.headers['authorization'];
    if (!authHeader || Array.isArray(authHeader)) {
      return undefined;
    }
    const [type, token] = authHeader.split(' ');
    return type === 'Bearer' ? token : undefined;
  }
}
