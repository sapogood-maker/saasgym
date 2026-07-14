import 'aula_status.dart';

/// A ocorrência concreta de uma Turma (docs/18, seção 2 item 4) — sempre
/// snapshot de Turma/Recorrência no momento da geração (MS6), nunca
/// referência viva. Uma vez criada, é um fato histórico: nunca é
/// modificada retroativamente por mudanças em Turma/Recorrência/
/// Professor/TurmaAluno. O Calendário (MS7) é só uma visão sobre esta
/// mesma entidade — cancelar muda `status`, nunca remove; professor
/// substituto é uma exceção pontual de `professorId`, nunca reflete em
/// Turma/Recorrência.
class Aula {
  const Aula({
    required this.id,
    required this.turmaId,
    required this.turmaNome,
    required this.modalidadeId,
    required this.modalidadeNome,
    required this.recorrenciaId,
    required this.data,
    required this.horaInicio,
    required this.duracaoMinutos,
    required this.professorId,
    required this.professorNome,
    required this.capacidadeMaxima,
    required this.status,
    required this.motivoCancelamento,
    required this.totalAlunos,
    required this.createdAt,
  });

  factory Aula.fromJson(Map<String, dynamic> json) {
    return Aula(
      id: json['id'] as String,
      turmaId: json['turmaId'] as String,
      turmaNome: json['turmaNome'] as String,
      modalidadeId: json['modalidadeId'] as String,
      modalidadeNome: json['modalidadeNome'] as String,
      recorrenciaId: json['recorrenciaId'] as String?,
      data: DateTime.parse(json['data'] as String),
      horaInicio: json['horaInicio'] as String,
      duracaoMinutos: json['duracaoMinutos'] as int,
      professorId: json['professorId'] as String,
      professorNome: json['professorNome'] as String,
      capacidadeMaxima: json['capacidadeMaxima'] as int?,
      status: AulaStatus.fromJson(json['status'] as String),
      motivoCancelamento: json['motivoCancelamento'] as String?,
      totalAlunos: json['totalAlunos'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String turmaId;
  final String turmaNome;

  /// Para o filtro por modalidade no Calendário (MS7).
  final String modalidadeId;
  final String modalidadeNome;

  /// Nulo = aula extra, sem recorrência por trás.
  final String? recorrenciaId;

  final DateTime data;
  final String horaInicio;
  final int duracaoMinutos;
  final String professorId;
  final String professorNome;

  /// Nulo = ilimitada — snapshot de `Turma.capacidadeMaxima`.
  final int? capacidadeMaxima;

  final AulaStatus status;
  final String? motivoCancelamento;
  final int totalAlunos;
  final DateTime createdAt;
}
