/// Snapshot atual (não histórico) dos indicadores de alunos do Relatório —
/// ver comentário em `RelatorioAlunosMensalItem`/backend
/// `RelatoriosService.resumo` sobre por que "ativos"/"retenção" não viram
/// série mês a mês.
class RelatorioResumo {
  const RelatorioResumo({
    required this.meses,
    required this.alunosAtivosHoje,
    required this.cancelamentosPeriodo,
    required this.taxaRetencaoAproximada,
  });

  factory RelatorioResumo.fromJson(Map<String, dynamic> json) {
    return RelatorioResumo(
      meses: json['meses'] as int,
      alunosAtivosHoje: json['alunosAtivosHoje'] as int,
      cancelamentosPeriodo: json['cancelamentosPeriodo'] as int,
      taxaRetencaoAproximada: (json['taxaRetencaoAproximada'] as num).toDouble(),
    );
  }

  final int meses;
  final int alunosAtivosHoje;
  final int cancelamentosPeriodo;
  final double taxaRetencaoAproximada;
}
