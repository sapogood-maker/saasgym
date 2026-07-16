import '../common/motivo_cancelamento.dart';

class CancelamentoPorMotivo {
  const CancelamentoPorMotivo({required this.motivo, required this.quantidade});

  factory CancelamentoPorMotivo.fromJson(Map<String, dynamic> json) {
    return CancelamentoPorMotivo(
      motivo: json['motivo'] == null
          ? null
          : MotivoCancelamento.fromJson(json['motivo'] as String),
      quantidade: json['quantidade'] as int,
    );
  }

  final MotivoCancelamento? motivo;
  final int quantidade;
}

/// Um mês da série "novos alunos x cancelamentos" do Relatório de Alunos —
/// sem curva de "ativos"/retenção por mês (ver `RelatorioResumo` pro
/// snapshot atual desses dois indicadores; o backend `RelatoriosService`
/// explica por que não dá pra reconstruir isso com exatidão pra meses
/// passados, sem histórico de status de Matrícula).
class RelatorioAlunosMensalItem {
  const RelatorioAlunosMensalItem({
    required this.mes,
    required this.ano,
    required this.novosAlunos,
    required this.cancelamentos,
    required this.cancelamentosPorMotivo,
    required this.saldoLiquido,
  });

  factory RelatorioAlunosMensalItem.fromJson(Map<String, dynamic> json) {
    return RelatorioAlunosMensalItem(
      mes: json['mes'] as int,
      ano: json['ano'] as int,
      novosAlunos: json['novosAlunos'] as int,
      cancelamentos: json['cancelamentos'] as int,
      cancelamentosPorMotivo: (json['cancelamentosPorMotivo'] as List)
          .cast<Map<String, dynamic>>()
          .map(CancelamentoPorMotivo.fromJson)
          .toList(),
      saldoLiquido: json['saldoLiquido'] as int,
    );
  }

  final int mes;
  final int ano;
  final int novosAlunos;
  final int cancelamentos;
  final List<CancelamentoPorMotivo> cancelamentosPorMotivo;
  final int saldoLiquido;
}
