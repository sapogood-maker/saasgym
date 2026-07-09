import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'user_profile.dart';

/// Perfil próprio (`/users/me`) — nome e foto. Troca de senha fica em
/// [AuthApi.changePassword] (`PATCH /auth/password`, já existente desde o
/// Sprint 1), não duplicada aqui.
class UsersApi {
  UsersApi(this._dio);

  final Dio _dio;

  Future<UserProfile> me() async {
    final response = await _dio.get<Map<String, dynamic>>('/users/me');
    return UserProfile.fromJson(response.data!);
  }

  Future<UserProfile> updateMe({required String nome}) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/users/me',
      data: {'nome': nome},
    );
    return UserProfile.fromJson(response.data!);
  }

  Future<UserProfile> uploadFoto({
    required Uint8List bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/users/me/foto',
      data: formData,
    );
    return UserProfile.fromJson(response.data!);
  }
}
