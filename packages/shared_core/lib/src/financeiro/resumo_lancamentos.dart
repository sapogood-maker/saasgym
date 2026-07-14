/// Resumo financeiro do período (Caixa) — soma real do backend, nunca
/// calculado client-side (a lista é paginada, somar só a página atual
/// daria conta errada).
class ResumoLancamentos {
  const ResumoLancamentos({
    required this.totalReceitas,
    required this.totalDespesas,
    required this.saldo,
    required this.quantidadeReceitas,
    required this.quantidadeDespesas,
  });

  factory ResumoLancamentos.fromJson(Map<String, dynamic> json) {
    return ResumoLancamentos(
      totalReceitas: (json['totalReceitas'] as num).toDouble(),
      totalDespesas: (json['totalDespesas'] as num).toDouble(),
      saldo: (json['saldo'] as num).toDouble(),
      quantidadeReceitas: json['quantidadeReceitas'] as int,
      quantidadeDespesas: json['quantidadeDespesas'] as int,
    );
  }

  final double totalReceitas;
  final double totalDespesas;
  final double saldo;
  final int quantidadeReceitas;
  final int quantidadeDespesas;
}
