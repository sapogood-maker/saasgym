/// Espelha o enum `PresencaStatus` do backend (Prisma). Mora
/// exclusivamente em `AulaAluno.presenca` (docs/18, seção 5, "Frequência
/// — invariante 1") — nunca em `Aula`, `Turma` ou `Matricula`.
enum PresencaStatus {
  presente('PRESENTE'),
  ausente('AUSENTE'),
  justificada('JUSTIFICADA');

  const PresencaStatus(this.wireValue);

  final String wireValue;

  static PresencaStatus fromJson(String value) {
    return PresencaStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => throw ArgumentError('PresencaStatus desconhecido: $value'),
    );
  }

  String toJson() => wireValue;
}
