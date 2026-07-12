import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'professor.dart';
import '../common/crud_api.dart';

class ProfessoresApi extends CrudApi<Professor> {
  ProfessoresApi(super.dio) : super(resourcePath: '/professores', fromJson: Professor.fromJson);

  Future<Professor> uploadFoto(
    String id, {
    required Uint8List bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await dio.post<Map<String, dynamic>>(
      '$resourcePath/$id/foto',
      data: formData,
    );
    return Professor.fromJson(response.data!);
  }
}
