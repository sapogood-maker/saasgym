/// Único ponto de contato que o resto do sistema conhece para notificar um
/// usuário — nenhum módulo de negócio importa uma implementação concreta
/// diretamente (mesmo desenho de `StorageProvider`, docs/21 decisão 7).
/// Sempre dirigida a um `User` específico (decisão 8); quando um evento
/// precisa avisar várias pessoas, o chamador faz o fan-out (uma chamada por
/// destinatário), a interface continua simples.
export interface NotificationPayload {
  userId: string;
  titulo: string;
  mensagem: string;
}

export interface NotificationProvider {
  notify(payload: NotificationPayload): Promise<void>;
}

export const NOTIFICATION_PROVIDER = Symbol('NOTIFICATION_PROVIDER');
