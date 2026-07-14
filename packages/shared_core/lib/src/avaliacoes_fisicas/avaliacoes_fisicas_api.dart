import 'package:dio/dio.dart';

import 'avaliacao_fisica.dart';
import '../common/paginated_result.dart';

/// API própria — **não** estende `CrudApi<T>` (mesmo critério de
/// `RecorrenciasApi`/`TurmaAlunosApi`/`AulasApi`/`AulaAlunosApi`, docs/20
/// decisão 4): sempre aninhada em `Aluno`, sem coleção de topo. Sem
/// `update` — `AvaliacaoFisica` é fato histórico imutável (docs/20 decisão
/// 1); corrigir um erro é `remove` (soft delete) + `create` de novo.
class AvaliacoesFisicasApi {
  AvaliacoesFisicasApi(this._dio);

  final Dio _dio;

  Future<AvaliacaoFisica> create(
    String alunoId, {
    required String data,
    required double peso,
    required double altura,
    String? observacoes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/alunos/$alunoId/avaliacoes-fisicas',
      data: {
        'data': data,
        'peso': peso,
        'altura': altura,
        'observacoes': ?observacoes,
      },
    );
    return AvaliacaoFisica.fromJson(response.data!);
  }

  Future<PaginatedResult<AvaliacaoFisica>> list(
    String alunoId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/alunos/$alunoId/avaliacoes-fisicas',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PaginatedResult.fromJson(response.data!, AvaliacaoFisica.fromJson);
  }

  Future<void> remove(String alunoId, String id) async {
    await _dio.delete<void>('/alunos/$alunoId/avaliacoes-fisicas/$id');
  }
}
