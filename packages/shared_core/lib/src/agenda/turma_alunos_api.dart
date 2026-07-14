import 'package:dio/dio.dart';

import 'turma_aluno.dart';
import '../common/user_status.dart';

/// API própria — **não** estende `CrudApi<T>`, mesmo critério de
/// `RecorrenciasApi` (docs/18, seção 2 item 3/6): sempre aninhada numa
/// Turma, sem paginação, e o "status" usa `UserStatus` mas via rota
/// própria `/status` (não um `update()` genérico) porque não há nenhum
/// outro campo editável em `TurmaAluno` — a única transição é
/// ativar/inativar a inscrição.
class TurmaAlunosApi {
  TurmaAlunosApi(this._dio);

  final Dio _dio;

  Future<List<TurmaAluno>> list(String turmaId) async {
    final response = await _dio.get<List<dynamic>>('/agenda/turmas/$turmaId/alunos');
    return response.data!.map((json) => TurmaAluno.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<TurmaAluno> create(String turmaId, String alunoId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/agenda/turmas/$turmaId/alunos',
      data: {'alunoId': alunoId},
    );
    return TurmaAluno.fromJson(response.data!);
  }

  Future<TurmaAluno> updateStatus(
    String turmaId,
    String id,
    UserStatus status, {
    String? motivo,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/agenda/turmas/$turmaId/alunos/$id/status',
      data: {'status': status.wireValue, 'motivo': ?motivo},
    );
    return TurmaAluno.fromJson(response.data!);
  }

  Future<void> remove(String turmaId, String id) async {
    await _dio.delete<void>('/agenda/turmas/$turmaId/alunos/$id');
  }
}
