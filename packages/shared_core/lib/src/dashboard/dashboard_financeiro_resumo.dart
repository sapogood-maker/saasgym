import '../financeiro/mensalidade_alerta.dart';

/// Seção financeira do Dashboard (Centro de Operações, docs/22) — resumo
/// do mês corrente + a lista combinada de alertas. Distinto de
/// `ResumoFinanceiro` (Painel Financeiro completo, com `mes`/`ano`
/// selecionáveis) — aqui é sempre o mês corrente, sem seletor.
class DashboardFinanceiroResumo {
  const DashboardFinanceiroResumo({
    required this.receitaPrevista,
    required this.receitaRecebida,
    required this.despesas,
    required this.saldo,
    required this.inadimplenciaValor,
    required this.inadimplenciaQuantidade,
    required this.mensalidadesAlerta,
  });

  factory DashboardFinanceiroResumo.fromJson(Map<String, dynamic> json) {
    return DashboardFinanceiroResumo(
      receitaPrevista: (json['receitaPrevista'] as num).toDouble(),
      receitaRecebida: (json['receitaRecebida'] as num).toDouble(),
      despesas: (json['despesas'] as num).toDouble(),
      saldo: (json['saldo'] as num).toDouble(),
      inadimplenciaValor: (json['inadimplenciaValor'] as num).toDouble(),
      inadimplenciaQuantidade: json['inadimplenciaQuantidade'] as int,
      mensalidadesAlerta: (json['mensalidadesAlerta'] as List)
          .cast<Map<String, dynamic>>()
          .map(MensalidadeAlerta.fromJson)
          .toList(),
    );
  }

  final double receitaPrevista;
  final double receitaRecebida;
  final double despesas;
  final double saldo;

  /// Sempre tempo real — todas as Mensalidade PENDENTE vencidas até hoje.
  final double inadimplenciaValor;
  final int inadimplenciaQuantidade;

  /// Vencidas + a vencer nos próximos 7 dias, combinadas e capadas em 10.
  final List<MensalidadeAlerta> mensalidadesAlerta;
}
