import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'aluno.dart';
import '../common/crud_api.dart';

class AlunosApi extends CrudApi<Aluno> {
  AlunosApi(super.dio) : super(resourcePath: '/alunos', fromJson: Aluno.fromJson);

  Future<Aluno> uploadFoto(
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
    return Aluno.fromJson(response.data!);
  }
}
