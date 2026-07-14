import 'recorrencia_tipo.dart';

/// Um padrão de repetição de uma Turma (docs/18, seção 2 item 3) —
/// pertence exclusivamente à Turma, nunca ao Professor; uma Turma pode ter
/// múltiplas Recorrências independentes (segunda/quarta, terça/quinta,
/// sábado, horário especial de férias etc.).
class Recorrencia {
  const Recorrencia({
    required this.id,
    required this.turmaId,
    required this.tipo,
    required this.diaSemana,
    required this.diaDoMes,
    required this.intervaloDias,
    required this.horaInicio,
    required this.duracaoMinutos,
    required this.professorId,
    required this.professorNome,
    required this.dataInicioVigencia,
    required this.dataFimVigencia,
    required this.ativo,
    required this.createdAt,
  });

  factory Recorrencia.fromJson(Map<String, dynamic> json) {
    return Recorrencia(
      id: json['id'] as String,
      turmaId: json['turmaId'] as String,
      tipo: RecorrenciaTipo.fromJson(json['tipo'] as String),
      diaSemana: json['diaSemana'] as int?,
      diaDoMes: json['diaDoMes'] as int?,
      intervaloDias: json['intervaloDias'] as int?,
      horaInicio: json['horaInicio'] as String,
      duracaoMinutos: json['duracaoMinutos'] as int,
      professorId: json['professorId'] as String?,
      professorNome: json['professorNome'] as String?,
      dataInicioVigencia: DateTime.parse(json['dataInicioVigencia'] as String),
      dataFimVigencia: json['dataFimVigencia'] != null
          ? DateTime.parse(json['dataFimVigencia'] as String)
          : null,
      ativo: json['ativo'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String turmaId;
  final RecorrenciaTipo tipo;

  /// 0 (domingo) a 6 (sábado) — presente só quando `tipo == semanal`.
  final int? diaSemana;

  /// 1-31 — presente só quando `tipo == mensal`.
  final int? diaDoMes;

  /// Ex.: 14 = quinzenal — presente só quando `tipo == intervalada`.
  final int? intervaloDias;

  final String horaInicio;
  final int duracaoMinutos;

  /// Override pontual do professor titular da Turma só para esta
  /// recorrência; nulo = usa o titular.
  final String? professorId;
  final String? professorNome;

  final DateTime dataInicioVigencia;
  final DateTime? dataFimVigencia;
  final bool ativo;
  final DateTime createdAt;
}
