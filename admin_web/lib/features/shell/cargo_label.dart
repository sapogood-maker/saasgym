import 'package:shared_core/shared_core.dart';

/// Rótulo amigável do papel do usuário — única fonte de verdade,
/// compartilhada entre `AppShell` (rodapé da sidebar) e `PerfilScreen`
/// (Sprint 31, Release Blockers v1.0: antes a tela de Perfil mostrava
/// `role.wireValue` cru, ex. `"ACADEMIA_ADMIN"`, enquanto a sidebar já
/// traduzia o mesmo dado corretamente — inconsistência visível lado a
/// lado na mesma tela).
String cargoLabel(Role role) => switch (role) {
  Role.systemAdmin => 'Administrador do sistema',
  Role.academiaAdmin => 'Administrador',
  Role.recepcionista => 'Recepção',
  Role.professor => 'Professor',
  Role.aluno => 'Aluno',
};
