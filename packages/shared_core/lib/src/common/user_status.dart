/// Status de Aluno/Professor, espelhando o enum `UserStatus` do backend
/// (reaproveitado — sem duplicar um enum ativo/inativo idêntico).
enum UserStatus {
  ativo('ATIVO'),
  inativo('INATIVO');

  const UserStatus(this.wireValue);

  final String wireValue;

  static UserStatus fromJson(String value) {
    return UserStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => throw ArgumentError('Status desconhecido: $value'),
    );
  }

  String toJson() => wireValue;
}
