import 'package:dio/dio.dart';

import 'recorrencia.dart';

/// API própria — **não** estende `CrudApi<T>` (docs/18, seção 2 item 3):
/// Recorrência é sempre aninhada numa Turma, sem paginação (a lista de uma
/// Turma cabe inteira numa tela), sem busca e sem `status: UserStatus`
/// (usa `ativo: bool` simples). Forçar o encaixe em `CrudApi<T>` só pra
/// reaproveitar a forma exigiria um filtro de status que não existe e uma
/// paginação que não faz sentido aqui — mesmo critério já registrado em
/// `project_saasgym_crudapi_updatestatus_debt`: revisar o encaixe quando
/// surge uma 2ª entidade parecida, não forçar a base a caber em todo mundo.
class RecorrenciasApi {
  RecorrenciasApi(this._dio);

  final Dio _dio;

  Future<List<Recorrencia>> list(String turmaId) async {
    final response = await _dio.get<List<dynamic>>('/agenda/turmas/$turmaId/recorrencias');
    return response.data!.map((json) => Recorrencia.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Recorrencia> create(String turmaId, Map<String, dynamic> dados) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/agenda/turmas/$turmaId/recorrencias',
      data: dados,
    );
    return Recorrencia.fromJson(response.data!);
  }

  Future<Recorrencia> update(String turmaId, String id, Map<String, dynamic> dados) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/agenda/turmas/$turmaId/recorrencias/$id',
      data: dados,
    );
    return Recorrencia.fromJson(response.data!);
  }

  Future<void> remove(String turmaId, String id) async {
    await _dio.delete<void>('/agenda/turmas/$turmaId/recorrencias/$id');
  }
}
