import '../common/periodicidade.dart';
import '../common/user_status.dart';

class Plano {
  const Plano({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.periodicidade,
    required this.valor,
    required this.quantidadeAulas,
    required this.ordem,
    required this.status,
    required this.createdAt,
  });

  factory Plano.fromJson(Map<String, dynamic> json) {
    return Plano(
      id: json['id'] as String,
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      periodicidade: Periodicidade.fromJson(json['periodicidade'] as String),
      valor: (json['valor'] as num).toDouble(),
      quantidadeAulas: json['quantidadeAulas'] as int?,
      ordem: json['ordem'] as int?,
      status: UserStatus.fromJson(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String nome;
  final String? descricao;
  final Periodicidade periodicidade;
  final double valor;
  final int? quantidadeAulas;
  final int? ordem;
  final UserStatus status;
  final DateTime createdAt;
}
