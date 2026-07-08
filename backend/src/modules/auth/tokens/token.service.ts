import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@prisma/client';
import { createHash, randomBytes } from 'node:crypto';
import { parseDurationToMs } from '../../../common/utils/duration';

export interface AccessTokenPayload {
  sub: string;
  academiaId: string | null;
  role: Role;
}

export interface IssuedRefreshToken {
  raw: string;
  hash: string;
  expiresAt: Date;
}

/// Emissão e hash de tokens. O access token é um JWT de vida curta; o
/// refresh token é opaco (aleatório, não é JWT) e hasheado com SHA-256 —
/// não bcrypt, que é para segredos de baixa entropia escolhidos por humanos
/// (senhas). Um token de 64 bytes já tem entropia suficiente; um hash
/// rápido é a escolha correta aqui, já que /auth/refresh acontece com muito
/// mais frequência que /auth/login.
@Injectable()
export class TokenService {
  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  signAccessToken(payload: AccessTokenPayload): Promise<string> {
    return this.jwtService.signAsync(payload, {
      secret: this.configService.get<string>('JWT_ACCESS_SECRET'),
      expiresIn: this.configService.get<string>('JWT_ACCESS_EXPIRATION'),
    });
  }

  issueRefreshToken(): IssuedRefreshToken {
    const raw = randomBytes(64).toString('hex');
    return {
      raw,
      hash: this.hashRefreshToken(raw),
      expiresAt: this.computeRefreshExpiry(),
    };
  }

  hashRefreshToken(raw: string): string {
    return createHash('sha256').update(raw).digest('hex');
  }

  private computeRefreshExpiry(): Date {
    const expiration = this.configService.get<string>('JWT_REFRESH_EXPIRATION', '7d');
    return new Date(Date.now() + parseDurationToMs(expiration));
  }
}
