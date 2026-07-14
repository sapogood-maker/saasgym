/// Espelha o enum `AulaAlunoTipo` do backend (Prisma).
enum AulaAlunoTipo {
  matriculado('MATRICULADO'),
  filaEspera('FILA_ESPERA'),
  reposicao('REPOSICAO');

  const AulaAlunoTipo(this.wireValue);

  final String wireValue;

  static AulaAlunoTipo fromJson(String value) {
    return AulaAlunoTipo.values.firstWhere(
      (tipo) => tipo.wireValue == value,
      orElse: () => throw ArgumentError('AulaAlunoTipo desconhecido: $value'),
    );
  }

  String toJson() => wireValue;
}
