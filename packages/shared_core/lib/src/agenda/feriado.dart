class Feriado {
  const Feriado({
    required this.id,
    required this.nome,
    required this.data,
    required this.createdAt,
  });

  factory Feriado.fromJson(Map<String, dynamic> json) {
    return Feriado(
      id: json['id'] as String,
      nome: json['nome'] as String,
      data: DateTime.parse(json['data'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String nome;
  final DateTime data;
  final DateTime createdAt;
}
