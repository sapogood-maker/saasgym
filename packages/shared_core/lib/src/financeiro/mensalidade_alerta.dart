/// Item da lista de alertas do Dashboard (Centro de Operações, docs/22) —
/// mensalidades PENDENTE já vencidas ou a vencer numa janela curta,
/// combinadas numa única lista acionável.
class MensalidadeAlerta {
  const MensalidadeAlerta({
    required this.id,
    required this.alunoId,
    required this.alunoNome,
    required this.valor,
    required this.dataVencimento,
    required this.vencida,
  });

  factory MensalidadeAlerta.fromJson(Map<String, dynamic> json) {
    return MensalidadeAlerta(
      id: json['id'] as String,
      alunoId: json['alunoId'] as String,
      alunoNome: json['alunoNome'] as String,
      valor: (json['valor'] as num).toDouble(),
      dataVencimento: DateTime.parse(json['dataVencimento'] as String),
      vencida: json['vencida'] as bool,
    );
  }

  final String id;
  final String alunoId;
  final String alunoNome;
  final double valor;
  final DateTime dataVencimento;

  /// `true` = já vencida; `false` = vence dentro da janela consultada.
  final bool vencida;
}
