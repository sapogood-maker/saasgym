import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'aluno.dart';
import '../common/paginated_result.dart';
import '../common/user_status.dart';

class AlunosApi {
  AlunosApi(this._dio);

  final Dio _dio;

  Future<PaginatedResult<Aluno>> list({
    String? search,
    UserStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/alunos',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null) 'status': status.wireValue,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return PaginatedResult.fromJson(response.data!, Aluno.fromJson);
  }

  Future<Aluno> get(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/alunos/$id');
    return Aluno.fromJson(response.data!);
  }

  Future<Aluno> create(Map<String, dynamic> dados) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/alunos',
      data: dados,
    );
    return Aluno.fromJson(response.data!);
  }

  Future<Aluno> update(String id, Map<String, dynamic> dados) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/alunos/$id',
      data: dados,
    );
    return Aluno.fromJson(response.data!);
  }

  Future<Aluno> updateStatus(
    String id,
    UserStatus status, {
    String? motivo,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/alunos/$id/status',
      data: {'status': status.wireValue, 'motivo': ?motivo},
    );
    return Aluno.fromJson(response.data!);
  }

  Future<void> remove(String id) async {
    await _dio.delete<void>('/alunos/$id');
  }

  Future<Aluno> uploadFoto(
    String id, {
    required Uint8List bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/alunos/$id/foto',
      data: formData,
    );
    return Aluno.fromJson(response.data!);
  }
}
