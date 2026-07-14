import '../common/user_status.dart';

class Modalidade {
  const Modalidade({
    required this.id,
    required this.nome,
    required this.cor,
    required this.status,
    required this.createdAt,
  });

  factory Modalidade.fromJson(Map<String, dynamic> json) {
    return Modalidade(
      id: json['id'] as String,
      nome: json['nome'] as String,
      cor: json['cor'] as String?,
      status: UserStatus.fromJson(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String nome;
  final String? cor;
  final UserStatus status;
  final DateTime createdAt;
}
