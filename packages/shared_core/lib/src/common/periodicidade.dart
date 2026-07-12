/// Espelha o enum `Periodicidade` do backend (Prisma) — periodicidade de
/// cobrança de um `Plano` da academia.
enum Periodicidade {
  mensal('MENSAL'),
  trimestral('TRIMESTRAL'),
  semestral('SEMESTRAL'),
  anual('ANUAL');

  const Periodicidade(this.wireValue);

  final String wireValue;

  static Periodicidade fromJson(String value) {
    return Periodicidade.values.firstWhere(
      (periodicidade) => periodicidade.wireValue == value,
      orElse: () => throw ArgumentError('Periodicidade desconhecida: $value'),
    );
  }

  String toJson() => wireValue;
}
