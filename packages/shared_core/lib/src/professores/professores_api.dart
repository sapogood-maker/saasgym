import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'professor.dart';
import '../common/paginated_result.dart';
import '../common/user_status.dart';

class ProfessoresApi {
  ProfessoresApi(this._dio);

  final Dio _dio;

  Future<PaginatedResult<Professor>> list({
    String? search,
    UserStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/professores',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null) 'status': status.wireValue,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return PaginatedResult.fromJson(response.data!, Professor.fromJson);
  }

  Future<Professor> get(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/professores/$id');
    return Professor.fromJson(response.data!);
  }

  Future<Professor> create(Map<String, dynamic> dados) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/professores',
      data: dados,
    );
    return Professor.fromJson(response.data!);
  }

  Future<Professor> update(String id, Map<String, dynamic> dados) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/professores/$id',
      data: dados,
    );
    return Professor.fromJson(response.data!);
  }

  Future<Professor> updateStatus(
    String id,
    UserStatus status, {
    String? motivo,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/professores/$id/status',
      data: {'status': status.wireValue, 'motivo': ?motivo},
    );
    return Professor.fromJson(response.data!);
  }

  Future<void> remove(String id) async {
    await _dio.delete<void>('/professores/$id');
  }

  Future<Professor> uploadFoto(
    String id, {
    required Uint8List bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/professores/$id/foto',
      data: formData,
    );
    return Professor.fromJson(response.data!);
  }
}
