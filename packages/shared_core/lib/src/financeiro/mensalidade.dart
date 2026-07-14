import '../common/forma_pagamento.dart';
import '../common/mensalidade_status.dart';

class Mensalidade {
  const Mensalidade({
    required this.id,
    required this.matriculaId,
    required this.alunoId,
    required this.alunoNome,
    required this.valor,
    required this.desconto,
    required this.multa,
    required this.valorFinal,
    required this.dataVencimento,
    required this.dataPagamento,
    required this.status,
    required this.atrasada,
    required this.motivoCancelamento,
    required this.formaPagamento,
    required this.createdAt,
  });

  factory Mensalidade.fromJson(Map<String, dynamic> json) {
    return Mensalidade(
      id: json['id'] as String,
      matriculaId: json['matriculaId'] as String,
      alunoId: json['alunoId'] as String,
      alunoNome: json['alunoNome'] as String,
      valor: (json['valor'] as num).toDouble(),
      desconto: (json['desconto'] as num).toDouble(),
      multa: (json['multa'] as num).toDouble(),
      valorFinal: (json['valorFinal'] as num).toDouble(),
      dataVencimento: DateTime.parse(json['dataVencimento'] as String),
      dataPagamento: json['dataPagamento'] != null
          ? DateTime.parse(json['dataPagamento'] as String)
          : null,
      status: MensalidadeStatus.fromJson(json['status'] as String),
      atrasada: json['atrasada'] as bool,
      motivoCancelamento: json['motivoCancelamento'] as String?,
      formaPagamento: json['formaPagamento'] != null
          ? FormaPagamento.fromJson(json['formaPagamento'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String matriculaId;
  final String alunoId;
  final String alunoNome;
  final double valor;
  final double desconto;
  final double multa;
  final double valorFinal;
  final DateTime dataVencimento;
  final DateTime? dataPagamento;
  final MensalidadeStatus status;
  final bool atrasada;
  final String? motivoCancelamento;
  final FormaPagamento? formaPagamento;
  final DateTime createdAt;
}
