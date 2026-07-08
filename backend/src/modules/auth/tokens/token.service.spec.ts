import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@prisma/client';
import { TokenService } from './token.service';

describe('TokenService', () => {
  let service: TokenService;
  let jwtService: { signAsync: jest.Mock };
  let configService: { get: jest.Mock };

  beforeEach(() => {
    jwtService = { signAsync: jest.fn().mockResolvedValue('jwt-assinado') };
    configService = {
      get: jest.fn((key: string, fallback?: unknown) => {
        const values: Record<string, string> = {
          JWT_ACCESS_SECRET: 'access-secret',
          JWT_ACCESS_EXPIRATION: '15m',
          JWT_REFRESH_EXPIRATION: '7d',
        };
        return values[key] ?? fallback;
      }),
    };

    service = new TokenService(
      jwtService as unknown as JwtService,
      configService as unknown as ConfigService,
    );
  });

  describe('signAccessToken', () => {
    it('assina com o secret e a expiração configurados', async () => {
      const payload = { sub: 'user-1', academiaId: 'academia-1', role: Role.ACADEMIA_ADMIN };

      const token = await service.signAccessToken(payload);

      expect(token).toBe('jwt-assinado');
      expect(jwtService.signAsync).toHaveBeenCalledWith(payload, {
        secret: 'access-secret',
        expiresIn: '15m',
      });
    });
  });

  describe('issueRefreshToken', () => {
    it('gera um token opaco (não-JWT) de alta entropia com hash e expiração', () => {
      const issued = service.issueRefreshToken();

      expect(issued.raw).toMatch(/^[0-9a-f]{128}$/); // 64 bytes em hex
      expect(issued.hash).toMatch(/^[0-9a-f]{64}$/); // sha256 em hex
      expect(issued.hash).toBe(service.hashRefreshToken(issued.raw));
      expect(issued.expiresAt.getTime()).toBeGreaterThan(Date.now());
    });

    it('cada token emitido é único', () => {
      const a = service.issueRefreshToken();
      const b = service.issueRefreshToken();

      expect(a.raw).not.toBe(b.raw);
      expect(a.hash).not.toBe(b.hash);
    });
  });

  describe('hashRefreshToken', () => {
    it('é determinístico (mesmo token cru -> mesmo hash)', () => {
      expect(service.hashRefreshToken('abc')).toBe(service.hashRefreshToken('abc'));
    });

    it('hashes diferentes para tokens diferentes', () => {
      expect(service.hashRefreshToken('abc')).not.toBe(service.hashRefreshToken('abd'));
    });
  });
});
