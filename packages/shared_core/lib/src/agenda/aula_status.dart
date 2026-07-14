/// Espelha o enum `AulaStatus` do backend (Prisma). "Realizada" não é um
/// valor aqui — é sempre calculado (`status == agendada && data < hoje`),
/// mesmo princípio de `Mensalidade.atrasada`.
enum AulaStatus {
  agendada('AGENDADA'),
  cancelada('CANCELADA');

  const AulaStatus(this.wireValue);

  final String wireValue;

  static AulaStatus fromJson(String value) {
    return AulaStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => throw ArgumentError('AulaStatus desconhecido: $value'),
    );
  }

  String toJson() => wireValue;
}
