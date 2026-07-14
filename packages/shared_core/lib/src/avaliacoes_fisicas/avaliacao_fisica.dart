/// Módulo 5 — histórico de medidas corporais do aluno. Fato histórico
/// imutável (docs/20, decisão 1): nunca editada, só criada ou removida
/// (soft delete, correção de erro de cadastro). `imc` sempre vem calculado
/// do backend (peso / (altura/100)²) — nunca armazenado (decisão 2).
class AvaliacaoFisica {
  const AvaliacaoFisica({
    required this.id,
    required this.alunoId,
    required this.data,
    required this.peso,
    required this.altura,
    required this.imc,
    required this.observacoes,
    required this.createdAt,
  });

  factory AvaliacaoFisica.fromJson(Map<String, dynamic> json) {
    return AvaliacaoFisica(
      id: json['id'] as String,
      alunoId: json['alunoId'] as String,
      data: DateTime.parse(json['data'] as String),
      peso: (json['peso'] as num).toDouble(),
      altura: (json['altura'] as num).toDouble(),
      imc: (json['imc'] as num).toDouble(),
      observacoes: json['observacoes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String alunoId;
  final DateTime data;

  /// kg
  final double peso;

  /// cm
  final double altura;

  final double imc;
  final String? observacoes;
  final DateTime createdAt;
}
