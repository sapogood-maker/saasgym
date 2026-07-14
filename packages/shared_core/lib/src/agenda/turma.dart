import '../common/user_status.dart';

/// O agrupamento lógico (docs/18-modulo-4-agenda-analise.md, "O papel de
/// Turma no domínio") — nome, modalidade, professor titular, capacidade,
/// local. Não representa aula, horário, recorrência nem presença; esses
/// campos não existem aqui de propósito.
class Turma {
  const Turma({
    required this.id,
    required this.nome,
    required this.modalidadeId,
    required this.modalidadeNome,
    required this.professorId,
    required this.professorNome,
    required this.capacidadeMaxima,
    required this.local,
    required this.status,
    required this.createdAt,
  });

  factory Turma.fromJson(Map<String, dynamic> json) {
    return Turma(
      id: json['id'] as String,
      nome: json['nome'] as String,
      modalidadeId: json['modalidadeId'] as String,
      modalidadeNome: json['modalidadeNome'] as String,
      professorId: json['professorId'] as String,
      professorNome: json['professorNome'] as String,
      capacidadeMaxima: json['capacidadeMaxima'] as int?,
      local: json['local'] as String?,
      status: UserStatus.fromJson(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String nome;
  final String modalidadeId;
  final String modalidadeNome;
  final String professorId;
  final String professorNome;

  /// Nulo = ilimitado, mesma convenção de `Plano.quantidadeAulas`.
  final int? capacidadeMaxima;
  final String? local;
  final UserStatus status;
  final DateTime createdAt;
}
