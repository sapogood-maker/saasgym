import 'package:dio/dio.dart';

import 'aula_aluno.dart';
import 'frequencia_aluno.dart';
import 'presenca_status.dart';
import '../common/paginated_result.dart';

/// API própria — **não** estende `CrudApi<T>` (mesmo critério de
/// `RecorrenciasApi`/`TurmaAlunosApi`/`AulasApi`): rotas sempre aninhadas
/// (em Aula ou em Aluno), e a única mutação (`registrarPresenca`) não é um
/// CRUD genérico — é a mesma operação pra criar e alterar uma presença
/// (docs/18, seção 5, "Frequência — invariante 4").
class AulaAlunosApi {
  AulaAlunosApi(this._dio);

  final Dio _dio;

  Future<List<AulaAluno>> listPorAula(String aulaId) async {
    final response = await _dio.get<List<dynamic>>('/agenda/aulas/$aulaId/alunos');
    return response.data!.map((json) => AulaAluno.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Registrar e alterar presença são a mesma chamada — mesmo princípio
  /// de `Recorrencia`/`Turma`: sem histórico de mudanças de presença, só
  /// o valor atual de `AulaAluno.presenca`.
  Future<AulaAluno> registrarPresenca(String aulaId, String id, PresencaStatus presenca) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/agenda/aulas/$aulaId/alunos/$id/presenca',
      data: {'presenca': presenca.wireValue},
    );
    return AulaAluno.fromJson(response.data!);
  }

  Future<PaginatedResult<FrequenciaAluno>> listPorAluno(
    String alunoId, {
    String? dataInicio,
    String? dataFim,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/agenda/alunos/$alunoId/frequencia',
      queryParameters: {
        'dataInicio': ?dataInicio,
        'dataFim': ?dataFim,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return PaginatedResult.fromJson(response.data!, FrequenciaAluno.fromJson);
  }
}
