import { Module } from '@nestjs/common';
import { NotificacoesController } from './notificacoes.controller';
import { NotificacoesService } from './notificacoes.service';
import { InternalNotificationProvider } from './internal-notification.provider';
import { NOTIFICATION_PROVIDER } from './notification-provider.interface';

/// Único módulo que sabe qual implementação concreta de NotificationProvider
/// está em uso — todo o resto do sistema injeta só NOTIFICATION_PROVIDER
/// (mesmo padrão de StorageModule/STORAGE_PROVIDER). Só o canal interno
/// existe nesta sprint (docs/21, decisão 7); um 2º canal (e-mail/WhatsApp/
/// push) se torna outra classe aqui, sem tocar em quem chama.
@Module({
  controllers: [NotificacoesController],
  providers: [
    NotificacoesService,
    { provide: NOTIFICATION_PROVIDER, useClass: InternalNotificationProvider },
  ],
  exports: [NOTIFICATION_PROVIDER],
})
export class NotificationsModule {}
