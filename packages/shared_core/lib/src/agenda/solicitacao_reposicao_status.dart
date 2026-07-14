/// Espelha o enum `SolicitacaoReposicaoStatus` do backend (Prisma).
enum SolicitacaoReposicaoStatus {
  pendente('PENDENTE'),
  aprovada('APROVADA'),
  rejeitada('REJEITADA');

  const SolicitacaoReposicaoStatus(this.wireValue);

  final String wireValue;

  static SolicitacaoReposicaoStatus fromJson(String value) {
    return SolicitacaoReposicaoStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => throw ArgumentError('SolicitacaoReposicaoStatus desconhecido: $value'),
    );
  }

  String toJson() => wireValue;
}
