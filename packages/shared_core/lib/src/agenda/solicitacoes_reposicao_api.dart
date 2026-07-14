import 'package:dio/dio.dart';

import 'solicitacao_reposicao.dart';
import 'solicitacao_reposicao_status.dart';
import '../common/paginated_result.dart';

/// API própria — **não** estende `CrudApi<T>` (mesmo critério de
/// `AulasApi`/`AulaAlunosApi`, docs/21 decisão 4/11): controller de topo
/// (não aninhado), sem `update()` genérico — `criar`/`aprovar`/`rejeitar`
/// são operações de estado, não CRUD.
class SolicitacoesReposicaoApi {
  SolicitacoesReposicaoApi(this._dio);

  final Dio _dio;

  /// Sem `aulaDestinoId` — a solicitação nasce só com a aula perdida
  /// (docs/21, decisão 3). O destino só existe a partir da aprovação.
  Future<SolicitacaoReposicao> criar(
    String aulaAlunoOrigemId, {
    String? observacoes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/agenda/solicitacoes-reposicao',
      data: {'aulaAlunoOrigemId': aulaAlunoOrigemId, 'observacoes': ?observacoes},
    );
    return SolicitacaoReposicao.fromJson(response.data!);
  }

  Future<PaginatedResult<SolicitacaoReposicao>> list({
    SolicitacaoReposicaoStatus? status,
    String? alunoId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/agenda/solicitacoes-reposicao',
      queryParameters: {
        'status': ?status?.wireValue,
        'alunoId': ?alunoId,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return PaginatedResult.fromJson(response.data!, SolicitacaoReposicao.fromJson);
  }

  /// A recepção escolhe a aula de destino agora — recontagem de capacidade
  /// em tempo real no backend (docs/21, decisão 3/5).
  Future<SolicitacaoReposicao> aprovar(String id, String aulaDestinoId) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/agenda/solicitacoes-reposicao/$id/aprovar',
      data: {'aulaDestinoId': aulaDestinoId},
    );
    return SolicitacaoReposicao.fromJson(response.data!);
  }

  Future<SolicitacaoReposicao> rejeitar(String id, {String? motivoRejeicao}) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/agenda/solicitacoes-reposicao/$id/rejeitar',
      data: {'motivoRejeicao': ?motivoRejeicao},
    );
    return SolicitacaoReposicao.fromJson(response.data!);
  }
}
