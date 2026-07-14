import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { ListNotificacoesQueryDto } from './dto/list-notificacoes-query.dto';
import { NotificacaoResponseDto, PaginatedNotificacoesResponseDto } from './dto/notificacao-response.dto';
import { PrismaService } from '../prisma/prisma.service';

/// Lado de leitura das notificações internas — distinto de
/// `NotificationProvider` (só escreve). "Listar"/"marcar como lida" são
/// específicos do canal interno (um e-mail/WhatsApp não tem "lida" dentro
/// do nosso sistema); por isso vivem aqui, não na interface do provider.
@Injectable()
export class NotificacoesService {
  constructor(private readonly prisma: PrismaService) {}

  /// Não-lidas primeiro, depois mais recentes — sem filtro de `lida` (evita
  /// o parsing de boolean em query string, sem precedente no projeto).
  async listMinhas(
    userId: string,
    query: ListNotificacoesQueryDto,
  ): Promise<PaginatedNotificacoesResponseDto> {
    const where: Prisma.NotificacaoWhereInput = { userId };

    const [items, total, naoLidas] = await Promise.all([
      this.prisma.forTenant().notificacao.findMany({
        where,
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: [{ lida: 'asc' }, { createdAt: 'desc' }],
      }),
      this.prisma.forTenant().notificacao.count({ where }),
      this.prisma.forTenant().notificacao.count({ where: { userId, lida: false } }),
    ]);

    return {
      items: items.map((notificacao) => this.toResponse(notificacao)),
      total,
      page: query.page,
      pageSize: query.pageSize,
      naoLidas,
    };
  }

  /// Nunca gera AuditLog (docs/21, decisão 10) — equivalente a "ler" um
  /// registro, nunca auditado em nenhum outro lugar do sistema.
  async marcarComoLida(userId: string, id: string): Promise<NotificacaoResponseDto> {
    const atual = await this.prisma.forTenant().notificacao.findFirst({ where: { id, userId } });
    if (!atual) {
      throw new NotFoundException('Notificação não encontrada');
    }

    const atualizada = atual.lida
      ? atual
      : await this.prisma.forTenant().notificacao.update({
          where: { id },
          data: { lida: true, lidaEm: new Date() },
        });

    return this.toResponse(atualizada);
  }

  private toResponse(notificacao: {
    id: string;
    titulo: string;
    mensagem: string;
    lida: boolean;
    lidaEm: Date | null;
    createdAt: Date;
  }): NotificacaoResponseDto {
    return {
      id: notificacao.id,
      titulo: notificacao.titulo,
      mensagem: notificacao.mensagem,
      lida: notificacao.lida,
      lidaEm: notificacao.lidaEm,
      createdAt: notificacao.createdAt,
    };
  }
}
