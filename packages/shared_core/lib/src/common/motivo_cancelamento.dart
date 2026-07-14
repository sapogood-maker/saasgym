/// Espelha o enum `MotivoCancelamento` do backend (Prisma) — categoria de
/// churn exigida ao cancelar uma `Matricula` (docs/16, item 10).
enum MotivoCancelamento {
  alunoSolicitou('ALUNO_SOLICITOU'),
  inadimplencia('INADIMPLENCIA'),
  academiaCancelou('ACADEMIA_CANCELOU'),
  outro('OUTRO');

  const MotivoCancelamento(this.wireValue);

  final String wireValue;

  static MotivoCancelamento fromJson(String value) {
    return MotivoCancelamento.values.firstWhere(
      (motivo) => motivo.wireValue == value,
      orElse: () => throw ArgumentError('Motivo de cancelamento desconhecido: $value'),
    );
  }

  String toJson() => wireValue;
}
