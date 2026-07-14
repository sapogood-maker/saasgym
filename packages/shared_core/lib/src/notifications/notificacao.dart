/// Notificação interna (Sprint 6, MS2) — canal único desta sprint do
/// `NotificationProvider` (docs/21, decisão 7). Sempre do usuário
/// autenticado (`GET notificacoes` já escopa por "minhas").
class Notificacao {
  const Notificacao({
    required this.id,
    required this.titulo,
    required this.mensagem,
    required this.lida,
    required this.lidaEm,
    required this.createdAt,
  });

  factory Notificacao.fromJson(Map<String, dynamic> json) {
    return Notificacao(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      mensagem: json['mensagem'] as String,
      lida: json['lida'] as bool,
      lidaEm: json['lidaEm'] != null ? DateTime.parse(json['lidaEm'] as String) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String titulo;
  final String mensagem;
  final bool lida;
  final DateTime? lidaEm;
  final DateTime createdAt;
}

/// Formato próprio (não `PaginatedResult<T>`) — carrega `naoLidas` (total
/// de não lidas, não só as desta página) pro badge do sino, sem precisar
/// de um 2º endpoint (docs/21, MS2).
class NotificacoesPaginadas {
  const NotificacoesPaginadas({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.naoLidas,
  });

  factory NotificacoesPaginadas.fromJson(Map<String, dynamic> json) {
    return NotificacoesPaginadas(
      items: (json['items'] as List).cast<Map<String, dynamic>>().map(Notificacao.fromJson).toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['pageSize'] as int,
      naoLidas: json['naoLidas'] as int,
    );
  }

  final List<Notificacao> items;
  final int total;
  final int page;
  final int pageSize;
  final int naoLidas;
}
