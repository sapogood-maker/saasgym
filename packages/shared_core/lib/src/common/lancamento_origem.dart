/// Espelha o enum `LancamentoOrigem` do backend (Prisma) — campo
/// autoritativo pra decidir se um Lancamento é editável/removível (evita
/// heurística baseada em `mensalidadeId != null`, docs/17, seção "MS4 —
/// Lançamento é cadastro ou Livro Caixa?").
enum LancamentoOrigem {
  manual('MANUAL'),
  mensalidade('MENSALIDADE');

  const LancamentoOrigem(this.wireValue);

  final String wireValue;

  static LancamentoOrigem fromJson(String value) {
    return LancamentoOrigem.values.firstWhere(
      (origem) => origem.wireValue == value,
      orElse: () => throw ArgumentError('Origem de lançamento desconhecida: $value'),
    );
  }

  String toJson() => wireValue;
}
