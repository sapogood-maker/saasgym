import '../common/forma_pagamento.dart';
import '../common/lancamento_origem.dart';
import '../common/lancamento_tipo.dart';

class Lancamento {
  const Lancamento({
    required this.id,
    required this.tipo,
    required this.origem,
    required this.descricao,
    required this.categoria,
    required this.valor,
    required this.data,
    required this.formaPagamento,
    required this.mensalidadeId,
    required this.alunoNome,
    required this.mensalidadeDataVencimento,
    required this.createdAt,
  });

  factory Lancamento.fromJson(Map<String, dynamic> json) {
    return Lancamento(
      id: json['id'] as String,
      tipo: LancamentoTipo.fromJson(json['tipo'] as String),
      origem: LancamentoOrigem.fromJson(json['origem'] as String),
      descricao: json['descricao'] as String,
      categoria: json['categoria'] as String?,
      valor: (json['valor'] as num).toDouble(),
      data: DateTime.parse(json['data'] as String),
      formaPagamento: json['formaPagamento'] != null
          ? FormaPagamento.fromJson(json['formaPagamento'] as String)
          : null,
      mensalidadeId: json['mensalidadeId'] as String?,
      alunoNome: json['alunoNome'] as String?,
      mensalidadeDataVencimento: json['mensalidadeDataVencimento'] != null
          ? DateTime.parse(json['mensalidadeDataVencimento'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final LancamentoTipo tipo;

  /// MANUAL (editável/removível) ou MENSALIDADE (gerado pelo sistema,
  /// somente leitura) — campo autoritativo, não inferir de `mensalidadeId`.
  final LancamentoOrigem origem;
  final String descricao;
  final String? categoria;
  final double valor;
  final DateTime data;
  final FormaPagamento? formaPagamento;
  final String? mensalidadeId;

  /// Só preenchido quando `origem == LancamentoOrigem.mensalidade` — nome
  /// do aluno pra exibir na linha do Caixa.
  final String? alunoNome;

  /// Só preenchido quando `origem == LancamentoOrigem.mensalidade` —
  /// competência (mês/ano) da Mensalidade de origem, pra navegar até ela
  /// em Mensalidades (que não tem tela de Detalhe própria, só a lista por
  /// competência).
  final DateTime? mensalidadeDataVencimento;

  final DateTime createdAt;
}
