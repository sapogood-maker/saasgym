import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { NotificationPayload, NotificationProvider } from './notification-provider.interface';
import { PrismaService } from '../prisma/prisma.service';

/// Único canal implementado nesta sprint (docs/21, decisão 7) — persiste
/// em `Notificacao`, sem e-mail/WhatsApp/push reais. Mesmo princípio de
/// `AuditService.record`: notificar nunca pode derrubar o fluxo principal
/// (criar/aprovar/rejeitar uma solicitação de reposição, por exemplo) —
/// erros de escrita são logados, nunca propagados.
@Injectable()
export class InternalNotificationProvider implements NotificationProvider {
  private readonly logger = new Logger(InternalNotificationProvider.name);

  constructor(private readonly prisma: PrismaService) {}

  async notify(payload: NotificationPayload): Promise<void> {
    try {
      await this.prisma.forTenant().notificacao.create({
        data: {
          userId: payload.userId,
          titulo: payload.titulo,
          mensagem: payload.mensagem,
        } as Prisma.NotificacaoUncheckedCreateInput,
      });
    } catch (error) {
      this.logger.error('Falha ao registrar notificação interna', error as Error);
    }
  }
}
