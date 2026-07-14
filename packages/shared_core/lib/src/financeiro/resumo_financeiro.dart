/// Indicadores do topo do Painel Financeiro (mês selecionado) — já vem
/// agregado do backend (`DashboardFinanceiroService`), nunca somado no
/// cliente. Taxa de recebimento (`receitaRecebida / receitaPrevista`) é
/// calculada no frontend — ver `taxaRecebimento` abaixo.
class ResumoFinanceiro {
  const ResumoFinanceiro({
    required this.mes,
    required this.ano,
    required this.receitaPrevista,
    required this.receitaRecebida,
    required this.despesas,
    required this.saldo,
    required this.inadimplenciaValor,
    required this.inadimplenciaQuantidade,
  });

  factory ResumoFinanceiro.fromJson(Map<String, dynamic> json) {
    return ResumoFinanceiro(
      mes: json['mes'] as int,
      ano: json['ano'] as int,
      receitaPrevista: (json['receitaPrevista'] as num).toDouble(),
      receitaRecebida: (json['receitaRecebida'] as num).toDouble(),
      despesas: (json['despesas'] as num).toDouble(),
      saldo: (json['saldo'] as num).toDouble(),
      inadimplenciaValor: (json['inadimplenciaValor'] as num).toDouble(),
      inadimplenciaQuantidade: json['inadimplenciaQuantidade'] as int,
    );
  }

  final int mes;
  final int ano;
  final double receitaPrevista;
  final double receitaRecebida;
  final double despesas;
  final double saldo;

  /// Sempre tempo real (todas as Mensalidade PENDENTE vencidas até hoje) —
  /// não escopado a `mes`/`ano`, diferente dos outros campos.
  final double inadimplenciaValor;
  final int inadimplenciaQuantidade;

  /// `null` quando não há receita prevista (evita dividir por zero ou
  /// inventar uma porcentagem sem sentido) — quem exibe decide o
  /// placeholder ("—").
  double? get taxaRecebimento => receitaPrevista <= 0 ? null : receitaRecebida / receitaPrevista;
}
