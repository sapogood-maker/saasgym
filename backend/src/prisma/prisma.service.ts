import {
  INestApplication,
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { TenantContextService } from '../common/context/tenant-context.service';
import { createTenantExtension } from '../common/prisma/prisma-tenant.extension';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor(private readonly tenantContext: TenantContextService) {
    super();
  }

  /// Client com isolamento automático por academiaId (lido do
  /// TenantContext) — use em qualquer service de negócio tenant-scoped.
  /// Fluxos inerentemente cross-tenant (login por e-mail, seed, gestão de
  /// academias pelo SYSTEM_ADMIN) continuam usando `this` diretamente.
  forTenant() {
    return this.$extends(createTenantExtension(this.tenantContext));
  }

  async onModuleInit() {
    await this.$connect();
    this.logger.log('Conexão com o PostgreSQL estabelecida');
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }

  async enableShutdownHooks(app: INestApplication) {
    process.on('beforeExit', () => {
      void app.close();
    });
  }
}
