import { Injectable, Logger } from '@nestjs/common';
import { AuditAction, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

export interface AuditEntry {
  action: AuditAction;
  userId?: string;
  academiaId?: string | null;
  identifier?: string;
  ipAddress?: string;
  userAgent?: string;
  metadata?: Prisma.InputJsonValue;
}

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  /// Auditoria nunca pode derrubar o fluxo principal (ex.: login) — erros
  /// de escrita são logados, nunca propagados.
  async record(entry: AuditEntry): Promise<void> {
    try {
      await this.prisma.auditLog.create({ data: { ...entry } });
    } catch (error) {
      this.logger.error('Falha ao registrar auditoria', error as Error);
    }
  }
}
