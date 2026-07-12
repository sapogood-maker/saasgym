import { Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { ConfigModule } from './config/config.module';
import { PrismaModule } from './prisma/prisma.module';
import { HealthModule } from './modules/health/health.module';
import { AuthModule } from './modules/auth/auth.module';
import { AdminModule } from './modules/admin/admin.module';
import { AlunosModule } from './modules/alunos/alunos.module';
import { ProfessoresModule } from './modules/professores/professores.module';
import { PlanosModule } from './modules/planos/planos.module';
import { MatriculasModule } from './modules/matriculas/matriculas.module';
import { DashboardModule } from './modules/dashboard/dashboard.module';
import { UsersModule } from './modules/users/users.module';
import { TenantContextModule } from './common/context/tenant-context.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';

@Module({
  imports: [
    ConfigModule,
    PrismaModule,
    TenantContextModule,
    EventEmitterModule.forRoot(),
    // Limite global — endpoints específicos (ex.: login) sobrescrevem com
    // @Throttle() para um limite mais restrito. Em NODE_ENV=test o limite
    // sobe bastante: os próprios testes e2e fazem dezenas de requisições em
    // segundos, e travariam contra o limite real de produção.
    ThrottlerModule.forRoot([
      { name: 'default', ttl: 60_000, limit: process.env.NODE_ENV === 'test' ? 1000 : 60 },
    ]),
    HealthModule,
    AuthModule,
    AdminModule,
    AlunosModule,
    ProfessoresModule,
    PlanosModule,
    MatriculasModule,
    DashboardModule,
    UsersModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
  ],
})
export class AppModule {}
