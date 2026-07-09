import '../common/user_status.dart';

class Professor {
  const Professor({
    required this.id,
    required this.fotoUrl,
    required this.nome,
    required this.cpf,
    required this.telefone,
    required this.email,
    required this.especialidade,
    required this.observacoes,
    required this.status,
    required this.createdAt,
  });

  factory Professor.fromJson(Map<String, dynamic> json) {
    return Professor(
      id: json['id'] as String,
      fotoUrl: json['fotoUrl'] as String?,
      nome: json['nome'] as String,
      cpf: json['cpf'] as String,
      telefone: json['telefone'] as String,
      email: json['email'] as String?,
      especialidade: json['especialidade'] as String?,
      observacoes: json['observacoes'] as String?,
      status: UserStatus.fromJson(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String? fotoUrl;
  final String nome;
  final String cpf;
  final String telefone;
  final String? email;
  final String? especialidade;
  final String? observacoes;
  final UserStatus status;
  final DateTime createdAt;
}
