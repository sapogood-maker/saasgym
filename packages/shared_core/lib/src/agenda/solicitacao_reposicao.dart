import 'solicitacao_reposicao_status.dart';

/// Sprint 6 (Agenda Avançada) — pedido de reposição de uma aula perdida.
/// `aulaDestinoId` é nulo até a aprovação (docs/21, decisão 3) — a
/// recepção escolhe o destino no momento de decidir, nunca na criação.
class SolicitacaoReposicao {
  const SolicitacaoReposicao({
    required this.id,
    required this.alunoId,
    required this.alunoNome,
    required this.aulaAlunoOrigemId,
    required this.aulaOrigemData,
    required this.aulaOrigemTurmaNome,
    required this.aulaDestinoId,
    required this.aulaDestinoData,
    required this.aulaDestinoTurmaNome,
    required this.status,
    required this.observacoes,
    required this.motivoRejeicao,
    required this.createdByUserId,
    required this.createdByUserNome,
    required this.decidedByUserId,
    required this.decidedByUserNome,
    required this.decidedAt,
    required this.createdAt,
  });

  factory SolicitacaoReposicao.fromJson(Map<String, dynamic> json) {
    return SolicitacaoReposicao(
      id: json['id'] as String,
      alunoId: json['alunoId'] as String,
      alunoNome: json['alunoNome'] as String,
      aulaAlunoOrigemId: json['aulaAlunoOrigemId'] as String,
      aulaOrigemData: DateTime.parse(json['aulaOrigemData'] as String),
      aulaOrigemTurmaNome: json['aulaOrigemTurmaNome'] as String,
      aulaDestinoId: json['aulaDestinoId'] as String?,
      aulaDestinoData:
          json['aulaDestinoData'] != null ? DateTime.parse(json['aulaDestinoData'] as String) : null,
      aulaDestinoTurmaNome: json['aulaDestinoTurmaNome'] as String?,
      status: SolicitacaoReposicaoStatus.fromJson(json['status'] as String),
      observacoes: json['observacoes'] as String?,
      motivoRejeicao: json['motivoRejeicao'] as String?,
      createdByUserId: json['createdByUserId'] as String,
      createdByUserNome: json['createdByUserNome'] as String,
      decidedByUserId: json['decidedByUserId'] as String?,
      decidedByUserNome: json['decidedByUserNome'] as String?,
      decidedAt: json['decidedAt'] != null ? DateTime.parse(json['decidedAt'] as String) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String alunoId;
  final String alunoNome;
  final String aulaAlunoOrigemId;
  final DateTime aulaOrigemData;
  final String aulaOrigemTurmaNome;

  /// Nulo até a aprovação.
  final String? aulaDestinoId;
  final DateTime? aulaDestinoData;
  final String? aulaDestinoTurmaNome;

  final SolicitacaoReposicaoStatus status;
  final String? observacoes;
  final String? motivoRejeicao;

  final String createdByUserId;
  final String createdByUserNome;
  final String? decidedByUserId;
  final String? decidedByUserNome;
  final DateTime? decidedAt;

  final DateTime createdAt;
}
