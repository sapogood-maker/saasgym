import 'aula_aluno_tipo.dart';
import 'aula_status.dart';
import 'presenca_status.dart';

/// Uma linha do histórico de frequência de um Aluno (consulta cross-aula,
/// MS8) — o mesmo `AulaAluno`, só que com o contexto da Aula embutido
/// (data, status, turma) pra exibir sem precisar de uma 2ª chamada por
/// linha.
class FrequenciaAluno {
  const FrequenciaAluno({
    required this.id,
    required this.aulaId,
    required this.aulaData,
    required this.aulaStatus,
    required this.turmaId,
    required this.turmaNome,
    required this.tipo,
    required this.presenca,
    required this.createdAt,
  });

  factory FrequenciaAluno.fromJson(Map<String, dynamic> json) {
    return FrequenciaAluno(
      id: json['id'] as String,
      aulaId: json['aulaId'] as String,
      aulaData: DateTime.parse(json['aulaData'] as String),
      aulaStatus: AulaStatus.fromJson(json['aulaStatus'] as String),
      turmaId: json['turmaId'] as String,
      turmaNome: json['turmaNome'] as String,
      tipo: AulaAlunoTipo.fromJson(json['tipo'] as String),
      presenca: json['presenca'] != null ? PresencaStatus.fromJson(json['presenca'] as String) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String aulaId;
  final DateTime aulaData;
  final AulaStatus aulaStatus;
  final String turmaId;
  final String turmaNome;
  final AulaAlunoTipo tipo;

  /// Nulo = ainda não marcado.
  final PresencaStatus? presenca;

  final DateTime createdAt;
}
