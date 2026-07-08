import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'role.dart';

/// Usuário autenticado no momento (dados vindos do JWT/endpoint /auth/me).
class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.nome,
    required this.email,
    required this.role,
    this.academiaId,
  });

  final String id;
  final String nome;
  final String email;
  final Role role;

  /// Nulo apenas para [Role.systemAdmin].
  final String? academiaId;
}

/// Estado de sessão: access token (em memória, nunca persistido) + usuário atual.
///
/// O refresh token nunca passa pelo estado do app: ele vive em um cookie
/// httpOnly controlado pelo backend (ver docs/03-fluxo-autenticacao.md).
class AuthSessionState {
  const AuthSessionState({this.accessToken, this.user});

  final String? accessToken;
  final AuthenticatedUser? user;

  bool get isAuthenticated => accessToken != null && user != null;

  AuthSessionState copyWith({String? accessToken, AuthenticatedUser? user}) {
    return AuthSessionState(
      accessToken: accessToken ?? this.accessToken,
      user: user ?? this.user,
    );
  }
}

/// Guarda o estado de autenticação atual do app.
///
/// O login/refresh/logout (chamadas HTTP reais) chegam no Sprint 1 junto com
/// o módulo `auth` do backend; aqui fica só o contrato de estado que os dois
/// frontends (admin_web e student_web) compartilham.
class AuthSessionNotifier extends Notifier<AuthSessionState> {
  @override
  AuthSessionState build() => const AuthSessionState();

  void setSession({required String accessToken, required AuthenticatedUser user}) {
    state = AuthSessionState(accessToken: accessToken, user: user);
  }

  void clear() {
    state = const AuthSessionState();
  }
}

final authSessionProvider = NotifierProvider<AuthSessionNotifier, AuthSessionState>(
  AuthSessionNotifier.new,
);
