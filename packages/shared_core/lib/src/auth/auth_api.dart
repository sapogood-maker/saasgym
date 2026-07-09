import 'package:dio/dio.dart';

import 'auth_session.dart';
import 'role.dart';

/// Chamadas HTTP de autenticação — login/logout. Refresh é tratado
/// automaticamente pelo interceptor do [ApiClient], nunca chamado daqui
/// diretamente. Compartilhado entre admin_web e student_web.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthSessionState> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data!;
    final userJson = data['user'] as Map<String, dynamic>;

    return AuthSessionState(
      accessToken: data['accessToken'] as String,
      user: AuthenticatedUser(
        id: userJson['id'] as String,
        nome: userJson['nome'] as String,
        email: userJson['email'] as String,
        role: Role.fromJson(userJson['role'] as String),
        academiaId: userJson['academiaId'] as String?,
      ),
    );
  }

  Future<void> logout() async {
    await _dio.post<void>('/auth/logout');
  }

  /// Revoga todas as sessões no backend (limpa o cookie de refresh) — quem
  /// chama isso precisa tratar a sessão local como encerrada em seguida.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.patch<void>(
      '/auth/password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }
}
