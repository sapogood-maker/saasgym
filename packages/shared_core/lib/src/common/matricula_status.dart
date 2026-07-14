/// Espelha o enum `MatriculaStatus` do backend (Prisma) — ciclo de vida de
/// uma `Matricula`, diferente do ATIVO/INATIVO genérico de `UserStatus`.
enum MatriculaStatus {
  ativa('ATIVA'),
  trancada('TRANCADA'),
  cancelada('CANCELADA'),
  encerrada('ENCERRADA');

  const MatriculaStatus(this.wireValue);

  final String wireValue;

  static MatriculaStatus fromJson(String value) {
    return MatriculaStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => throw ArgumentError('Status de matrícula desconhecido: $value'),
    );
  }

  String toJson() => wireValue;
}
