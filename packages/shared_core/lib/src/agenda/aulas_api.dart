import 'package:dio/dio.dart';

import 'aula.dart';
import 'aula_status.dart';
import 'gerar_aulas_resultado.dart';
import '../common/paginated_result.dart';

/// API própria — **não** estende `CrudApi<T>` (mesmo critério de
/// `RecorrenciasApi`/`TurmaAlunosApi`, docs/18 seção 2 item 3/6): a
/// geração/listagem por Turma (MS6) é sempre aninhada, e as operações do
/// Calendário (MS7) — cancelar/substituto/aula extra — têm payload e
/// semântica próprios, sem `update()`/`updateStatus()` genérico.
/// `dataInicio`/`dataFim` chegam já formatados (`yyyy-MM-dd`) por quem
/// chama, mesmo padrão de `RecorrenciasApi`.
class AulasApi {
  AulasApi(this._dio);

  final Dio _dio;

  Future<GerarAulasResultado> gerar(
    String turmaId, {
    required String dataInicio,
    required String dataFim,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/agenda/turmas/$turmaId/aulas/gerar',
      data: {'dataInicio': dataInicio, 'dataFim': dataFim},
    );
    return GerarAulasResultado.fromJson(response.data!);
  }

  Future<PaginatedResult<Aula>> list(
    String turmaId, {
    String? dataInicio,
    String? dataFim,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/agenda/turmas/$turmaId/aulas',
      queryParameters: {
        'dataInicio': ?dataInicio,
        'dataFim': ?dataFim,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return PaginatedResult.fromJson(response.data!, Aula.fromJson);
  }

  /// Calendário (MS7) — lista aulas da academia inteira (não aninhado numa
  /// Turma), com os 4 filtros já previstos desde a análise de domínio.
  Future<PaginatedResult<Aula>> listCalendario({
    String? dataInicio,
    String? dataFim,
    String? turmaId,
    String? professorId,
    String? modalidadeId,
    AulaStatus? status,
    int page = 1,
    int pageSize = 100,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/agenda/aulas',
      queryParameters: {
        'dataInicio': ?dataInicio,
        'dataFim': ?dataFim,
        'turmaId': ?turmaId,
        'professorId': ?professorId,
        'modalidadeId': ?modalidadeId,
        'status': ?status?.wireValue,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return PaginatedResult.fromJson(response.data!, Aula.fromJson);
  }

  Future<Aula> getOne(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/agenda/aulas/$id');
    return Aula.fromJson(response.data!);
  }

  /// Cancelamento (docs/18, "Calendário — invariante 2") — só muda
  /// `status`, nunca remove a Aula.
  Future<Aula> cancelar(String id, {String? motivoCancelamento}) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/agenda/aulas/$id/cancelar',
      data: {'motivoCancelamento': ?motivoCancelamento},
    );
    return Aula.fromJson(response.data!);
  }

  /// Professor substituto (docs/18, "Calendário — invariante 3") — só
  /// altera `Aula.professorId`, nunca Turma/Recorrencia.
  Future<Aula> definirSubstituto(String id, String professorId) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/agenda/aulas/$id/substituto',
      data: {'professorId': professorId},
    );
    return Aula.fromJson(response.data!);
  }

  /// Aula extra (docs/18, "Calendário — invariante 4") — sempre uma Aula
  /// independente, nunca cria/altera Recorrencia.
  Future<Aula> criarExtra({
    required String turmaId,
    required String data,
    required String horaInicio,
    required int duracaoMinutos,
    String? professorId,
    int? capacidadeMaxima,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/agenda/aulas/extra',
      data: {
        'turmaId': turmaId,
        'data': data,
        'horaInicio': horaInicio,
        'duracaoMinutos': duracaoMinutos,
        'professorId': ?professorId,
        'capacidadeMaxima': ?capacidadeMaxima,
      },
    );
    return Aula.fromJson(response.data!);
  }

  /// Correção de cadastro (soft delete) — nunca usado pelo cancelamento
  /// normal (esse é `cancelar()`, que só muda `status`).
  Future<void> remove(String id) async {
    await _dio.delete<void>('/agenda/aulas/$id');
  }
}
