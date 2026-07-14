import '../common/matricula_status.dart';
import '../common/motivo_cancelamento.dart';

class Matricula {
  const Matricula({
    required this.id,
    required this.alunoId,
    required this.alunoNome,
    required this.alunoFotoUrl,
    required this.planoId,
    required this.planoNome,
    required this.createdByUserId,
    required this.valor,
    required this.diaVencimento,
    required this.dataInicio,
    required this.dataFimPrevista,
    required this.dataFim,
    required this.status,
    required this.trancadoEm,
    required this.trancamentoMotivo,
    required this.motivoCancelamento,
    required this.motivoCancelamentoDetalhe,
    required this.matriculaAnteriorId,
    required this.createdAt,
  });

  factory Matricula.fromJson(Map<String, dynamic> json) {
    return Matricula(
      id: json['id'] as String,
      alunoId: json['alunoId'] as String,
      alunoNome: json['alunoNome'] as String,
      alunoFotoUrl: json['alunoFotoUrl'] as String?,
      planoId: json['planoId'] as String,
      planoNome: json['planoNome'] as String,
      createdByUserId: json['createdByUserId'] as String,
      valor: (json['valor'] as num).toDouble(),
      diaVencimento: json['diaVencimento'] as int,
      dataInicio: DateTime.parse(json['dataInicio'] as String),
      dataFimPrevista: DateTime.parse(json['dataFimPrevista'] as String),
      dataFim: DateTime.parse(json['dataFim'] as String),
      status: MatriculaStatus.fromJson(json['status'] as String),
      trancadoEm: json['trancadoEm'] != null
          ? DateTime.parse(json['trancadoEm'] as String)
          : null,
      trancamentoMotivo: json['trancamentoMotivo'] as String?,
      motivoCancelamento: json['motivoCancelamento'] != null
          ? MotivoCancelamento.fromJson(json['motivoCancelamento'] as String)
          : null,
      motivoCancelamentoDetalhe: json['motivoCancelamentoDetalhe'] as String?,
      matriculaAnteriorId: json['matriculaAnteriorId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String alunoId;
  final String alunoNome;
  final String? alunoFotoUrl;
  final String planoId;
  final String planoNome;
  final String createdByUserId;
  final double valor;
  final int diaVencimento;
  final DateTime dataInicio;
  final DateTime dataFimPrevista;
  final DateTime dataFim;
  final MatriculaStatus status;
  final DateTime? trancadoEm;
  final String? trancamentoMotivo;
  final MotivoCancelamento? motivoCancelamento;
  final String? motivoCancelamentoDetalhe;
  final String? matriculaAnteriorId;
  final DateTime createdAt;
}
