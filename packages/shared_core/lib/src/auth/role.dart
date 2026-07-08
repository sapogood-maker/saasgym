/// Perfis de acesso, espelhando o enum `Role` do backend (Prisma).
enum Role {
  systemAdmin('SYSTEM_ADMIN'),
  academiaAdmin('ACADEMIA_ADMIN'),
  recepcionista('RECEPCIONISTA'),
  professor('PROFESSOR'),
  aluno('ALUNO');

  const Role(this.wireValue);

  /// Valor exatamente como o backend serializa o enum `Role`.
  final String wireValue;

  static Role fromJson(String value) {
    return Role.values.firstWhere(
      (role) => role.wireValue == value,
      orElse: () => throw ArgumentError('Role desconhecida: $value'),
    );
  }

  String toJson() => wireValue;
}
