import '../common/user_status.dart';

/// A inscrição permanente do aluno na Turma (docs/18, seção 2 item 6) —
/// nunca cria, altera ou remove `AulaAluno`; isso só acontece no gerador
/// de Aulas (MS6), como snapshot dos `TurmaAluno` ativos naquele momento.
class TurmaAluno {
  const TurmaAluno({
    required this.id,
    required this.turmaId,
    required this.alunoId,
    required this.alunoNome,
    required this.matriculaId,
    required this.status,
    required this.dataInicio,
    required this.dataFim,
    required this.createdAt,
  });

  factory TurmaAluno.fromJson(Map<String, dynamic> json) {
    return TurmaAluno(
      id: json['id'] as String,
      turmaId: json['turmaId'] as String,
      alunoId: json['alunoId'] as String,
      alunoNome: json['alunoNome'] as String,
      matriculaId: json['matriculaId'] as String,
      status: UserStatus.fromJson(json['status'] as String),
      dataInicio: DateTime.parse(json['dataInicio'] as String),
      dataFim: json['dataFim'] != null ? DateTime.parse(json['dataFim'] as String) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String turmaId;
  final String alunoId;
  final String alunoNome;
  final String matriculaId;
  final UserStatus status;
  final DateTime dataInicio;
  final DateTime? dataFim;
  final DateTime createdAt;
}
