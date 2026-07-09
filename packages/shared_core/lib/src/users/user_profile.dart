import '../auth/role.dart';

/// Perfil do usuário autenticado, incluindo o que `AuthenticatedUser` não tem
/// (foto) — retornado por `GET/PATCH /users/me`.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.nome,
    required this.email,
    required this.role,
    required this.academiaId,
    required this.fotoUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      nome: json['nome'] as String,
      email: json['email'] as String,
      role: Role.fromJson(json['role'] as String),
      academiaId: json['academiaId'] as String?,
      fotoUrl: json['fotoUrl'] as String?,
    );
  }

  final String id;
  final String nome;
  final String email;
  final Role role;
  final String? academiaId;
  final String? fotoUrl;
}
