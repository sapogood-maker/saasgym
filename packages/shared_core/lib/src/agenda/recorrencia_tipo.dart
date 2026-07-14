/// Espelha o enum `RecorrenciaTipo` do backend (Prisma) — qual campo é
/// relevante (`diaSemana`/`diaDoMes`/`intervaloDias`) depende deste tipo.
enum RecorrenciaTipo {
  semanal('SEMANAL'),
  mensal('MENSAL'),
  intervalada('INTERVALADA');

  const RecorrenciaTipo(this.wireValue);

  final String wireValue;

  static RecorrenciaTipo fromJson(String value) {
    return RecorrenciaTipo.values.firstWhere(
      (tipo) => tipo.wireValue == value,
      orElse: () => throw ArgumentError('RecorrenciaTipo desconhecido: $value'),
    );
  }

  String toJson() => wireValue;
}
