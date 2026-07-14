/// Espelha o enum `LancamentoTipo` do backend (Prisma).
enum LancamentoTipo {
  receita('RECEITA'),
  despesa('DESPESA');

  const LancamentoTipo(this.wireValue);

  final String wireValue;

  static LancamentoTipo fromJson(String value) {
    return LancamentoTipo.values.firstWhere(
      (tipo) => tipo.wireValue == value,
      orElse: () => throw ArgumentError('Tipo de lançamento desconhecido: $value'),
    );
  }

  String toJson() => wireValue;
}
