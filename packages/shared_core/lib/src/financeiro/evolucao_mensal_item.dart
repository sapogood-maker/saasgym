/// Um mês da série "evolução mensal" do Painel Financeiro — mesmos 4
/// valores agregados do resumo do mês, sem a inadimplência (que é sempre
/// tempo real, não faz sentido por competência histórica).
class EvolucaoMensalItem {
  const EvolucaoMensalItem({
    required this.mes,
    required this.ano,
    required this.receitaPrevista,
    required this.receitaRecebida,
    required this.despesas,
    required this.saldo,
  });

  factory EvolucaoMensalItem.fromJson(Map<String, dynamic> json) {
    return EvolucaoMensalItem(
      mes: json['mes'] as int,
      ano: json['ano'] as int,
      receitaPrevista: (json['receitaPrevista'] as num).toDouble(),
      receitaRecebida: (json['receitaRecebida'] as num).toDouble(),
      despesas: (json['despesas'] as num).toDouble(),
      saldo: (json['saldo'] as num).toDouble(),
    );
  }

  final int mes;
  final int ano;
  final double receitaPrevista;
  final double receitaRecebida;
  final double despesas;
  final double saldo;

  /// Mesma lógica de `ResumoFinanceiro.taxaRecebimento` — `null` sem
  /// receita prevista naquele mês, evita inventar porcentagem.
  double? get taxaRecebimento => receitaPrevista <= 0 ? null : receitaRecebida / receitaPrevista;
}
