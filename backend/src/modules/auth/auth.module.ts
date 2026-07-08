import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { AuditModule } from '../audit/audit.module';
import { TokenService } from './tokens/token.service';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantContextInterceptor } from '../../common/interceptors/tenant-context.interceptor';

@Module({
  imports: [JwtModule.register({}), AuditModule],
  controllers: [AuthController],
  providers: [
    TokenService,
    AuthService,
    // Globais: toda rota exige access token por padrão (@Public() libera) e
    // todo request autenticado popula o TenantContext antes do handler.
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_INTERCEPTOR, useClass: TenantContextInterceptor },
  ],
  exports: [TokenService],
})
export class AuthModule {}
