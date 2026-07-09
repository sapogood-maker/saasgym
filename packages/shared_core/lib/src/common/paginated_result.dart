/// Resultado paginado — mesmo formato usado por `/alunos` e `/professores`
/// (`{ items, total, page, pageSize }`).
class PaginatedResult<T> {
  const PaginatedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory PaginatedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PaginatedResult(
      items: (json['items'] as List)
          .cast<Map<String, dynamic>>()
          .map(fromJsonT)
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['pageSize'] as int,
    );
  }

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  int get totalPaginas => (total / pageSize).ceil().clamp(1, 1 << 31);
}
