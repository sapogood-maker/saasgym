import 'aula_aluno_tipo.dart';
import 'presenca_status.dart';

/// O vínculo por ocorrência (docs/18, seção 2 item 5) — presença, fila de
/// espera e reposição vivem todos aqui, sem entidades próprias.
/// `presenca` é o único lugar do domínio onde presença mora (MS8,
/// "Frequência — invariante 1"): nunca em `Aula`, `Turma` ou `Matricula`.
class AulaAluno {
  const AulaAluno({
    required this.id,
    required this.aulaId,
    required this.alunoId,
    required this.alunoNome,
    required this.turmaAlunoId,
    required this.tipo,
    required this.presenca,
    required this.createdAt,
  });

  factory AulaAluno.fromJson(Map<String, dynamic> json) {
    return AulaAluno(
      id: json['id'] as String,
      aulaId: json['aulaId'] as String,
      alunoId: json['alunoId'] as String,
      alunoNome: json['alunoNome'] as String,
      turmaAlunoId: json['turmaAlunoId'] as String?,
      tipo: AulaAlunoTipo.fromJson(json['tipo'] as String),
      presenca: json['presenca'] != null ? PresencaStatus.fromJson(json['presenca'] as String) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String aulaId;
  final String alunoId;
  final String alunoNome;

  /// Nulo quando a origem não é a matrícula permanente na turma.
  final String? turmaAlunoId;

  final AulaAlunoTipo tipo;

  /// Nulo = ainda não marcado.
  final PresencaStatus? presenca;

  final DateTime createdAt;
}
