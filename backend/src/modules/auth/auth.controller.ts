import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Patch,
  Post,
  Req,
  Res,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { Request, Response } from 'express';
import { AuthService } from './auth.service';
import { ChangePasswordDto } from './dto/change-password.dto';
import { LoginDto } from './dto/login.dto';
import { LoginResponseDto, UserProfileDto } from './dto/user-profile.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { AuthenticatedUser } from '../../common/types/authenticated-user.interface';

const REFRESH_COOKIE_NAME = 'refreshToken';

// Lido uma vez, na carga do módulo (decorators são avaliados no import, não
// por requisição) — em NODE_ENV=test o limite sobe bastante, senão os
// próprios testes e2e (dezenas de logins em segundos) tropeçariam nele.
const LOGIN_THROTTLE_LIMIT = process.env.NODE_ENV === 'test' ? 1000 : 5;

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly configService: ConfigService,
  ) {}

  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  // Limite bem mais restrito que o global — mitiga força bruta de senha.
  @Throttle({ default: { limit: LOGIN_THROTTLE_LIMIT, ttl: 60_000 } })
  @ApiOperation({ summary: 'Login — retorna o access token e define o cookie de refresh' })
  async login(
    @Body() dto: LoginDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<LoginResponseDto> {
    const result = await this.authService.login(dto.email, dto.password, {
      ipAddress: req.ip,
      userAgent: req.headers['user-agent'],
    });

    this.setRefreshCookie(res, result.refreshToken, result.refreshTokenExpiresAt);

    return { accessToken: result.accessToken, user: result.user };
  }

  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Rotaciona o refresh token (cookie) e emite um novo access token' })
  async refresh(
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<{ accessToken: string }> {
    const rawToken = this.extractRefreshCookie(req);
    if (!rawToken) {
      throw new UnauthorizedException('Refresh token ausente');
    }

    const result = await this.authService.refresh(rawToken, {
      ipAddress: req.ip,
      userAgent: req.headers['user-agent'],
    });

    this.setRefreshCookie(res, result.refreshToken, result.refreshTokenExpiresAt);

    return { accessToken: result.accessToken };
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Revoga a sessão atual (refresh token) e limpa o cookie' })
  async logout(
    @CurrentUser() user: AuthenticatedUser,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<{ success: true }> {
    const rawToken = this.extractRefreshCookie(req);

    await this.authService.logout(user.userId, user.academiaId, rawToken, {
      ipAddress: req.ip,
      userAgent: req.headers['user-agent'],
    });

    res.clearCookie(REFRESH_COOKIE_NAME, { path: this.refreshCookiePath() });

    return { success: true };
  }

  @Get('me')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Usuário autenticado atual' })
  me(@CurrentUser() user: AuthenticatedUser): Promise<UserProfileDto> {
    return this.authService.me(user.userId);
  }

  @Patch('password')
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Troca a senha do usuário autenticado e revoga todas as sessões' })
  async changePassword(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: ChangePasswordDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<{ success: true }> {
    await this.authService.changePassword(
      user.userId,
      user.academiaId,
      dto.currentPassword,
      dto.newPassword,
      { ipAddress: req.ip, userAgent: req.headers['user-agent'] },
    );

    res.clearCookie(REFRESH_COOKIE_NAME, { path: this.refreshCookiePath() });

    return { success: true };
  }

  private extractRefreshCookie(req: Request): string | undefined {
    return (req.cookies as Record<string, string> | undefined)?.[REFRESH_COOKIE_NAME];
  }

  // Precisa do prefixo público (PUBLIC_API_PREFIX) para que o Path do cookie
  // bata com a URL que o navegador realmente chamou — atrás de um proxy que
  // publica a API sob um path externo (ex.: "/saasgym-api" em vez de um
  // domínio próprio), o path interno sozinho ("/api/auth") nunca combina com
  // a requisição vista pelo browser, e o cookie simplesmente não volta.
  private refreshCookiePath(): string {
    return `${this.configService.get<string>('PUBLIC_API_PREFIX', '')}/api/auth`;
  }

  private setRefreshCookie(res: Response, token: string, expiresAt: Date): void {
    const isProduction = this.configService.get<string>('NODE_ENV') === 'production';

    res.cookie(REFRESH_COOKIE_NAME, token, {
      httpOnly: true,
      secure: isProduction,
      sameSite: isProduction ? 'none' : 'lax',
      expires: expiresAt,
      path: this.refreshCookiePath(),
    });
  }
}
