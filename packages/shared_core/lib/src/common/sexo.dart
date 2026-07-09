/// Espelha o enum `Sexo` do backend (Prisma).
enum Sexo {
  masculino('MASCULINO'),
  feminino('FEMININO'),
  outro('OUTRO');

  const Sexo(this.wireValue);

  final String wireValue;

  static Sexo fromJson(String value) {
    return Sexo.values.firstWhere(
      (sexo) => sexo.wireValue == value,
      orElse: () => throw ArgumentError('Sexo desconhecido: $value'),
    );
  }

  String toJson() => wireValue;
}
