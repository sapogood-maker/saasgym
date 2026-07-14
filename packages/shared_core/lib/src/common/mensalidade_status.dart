/// Espelha o enum `MensalidadeStatus` do backend (Prisma) — "atrasada" não
/// é um valor aqui, é sempre calculado (`Mensalidade.atrasada`, já vem
/// pronto do backend) — ver docs/17-modulo-3-financeiro-analise.md, item 1.
enum MensalidadeStatus {
  pendente('PENDENTE'),
  paga('PAGA'),
  cancelada('CANCELADA');

  const MensalidadeStatus(this.wireValue);

  final String wireValue;

  static MensalidadeStatus fromJson(String value) {
    return MensalidadeStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => throw ArgumentError('Status de mensalidade desconhecido: $value'),
    );
  }

  String toJson() => wireValue;
}
