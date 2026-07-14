import 'matricula.dart';
import '../common/crud_api.dart';
import '../common/matricula_status.dart';
import '../common/motivo_cancelamento.dart';
import '../common/paginated_result.dart';

/// Única entidade cujo ciclo de vida não cabe no `updateStatus` genérico da
/// base — trancar/reativar/cancelar/renovar são endpoints dedicados (ver
/// comentário em MatriculasService, backend). `list()` herdado também não
/// serve: além de `search`, filtra por `alunoId`/`planoId`/`status`
/// (`MatriculaStatus`, não `UserStatus`) — daí `listMatriculas` como método
/// próprio, não um override (named param `status` com tipo incompatível não
/// seria um override válido em Dart). `search` busca por `Aluno.nome`
/// (contains, case-insensitive) no backend — não é um filtro local.
class MatriculasApi extends CrudApi<Matricula> {
  MatriculasApi(super.dio) : super(resourcePath: '/matriculas', fromJson: Matricula.fromJson);

  Future<PaginatedResult<Matricula>> listMatriculas({
    String? search,
    String? alunoId,
    String? planoId,
    MatriculaStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      resourcePath,
      queryParameters: {
        'search': ?search,
        'alunoId': ?alunoId,
        'planoId': ?planoId,
        if (status != null) 'status': status.wireValue,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return PaginatedResult.fromJson(response.data!, fromJson);
  }

  Future<Matricula> trancar(String id, {String? motivo}) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '$resourcePath/$id/trancar',
      data: {'motivo': ?motivo},
    );
    return fromJson(response.data!);
  }

  Future<Matricula> reativar(String id) async {
    final response = await dio.patch<Map<String, dynamic>>('$resourcePath/$id/reativar');
    return fromJson(response.data!);
  }

  Future<Matricula> cancelar(
    String id, {
    required MotivoCancelamento motivoCancelamento,
    String? motivoCancelamentoDetalhe,
  }) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '$resourcePath/$id/cancelar',
      data: {
        'motivoCancelamento': motivoCancelamento.wireValue,
        'motivoCancelamentoDetalhe': ?motivoCancelamentoDetalhe,
      },
    );
    return fromJson(response.data!);
  }

  Future<Matricula> renovar(
    String id, {
    String? dataInicio,
    num? valor,
    int? diaVencimento,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '$resourcePath/$id/renovar',
      data: {
        'dataInicio': ?dataInicio,
        'valor': ?valor,
        'diaVencimento': ?diaVencimento,
      },
    );
    return fromJson(response.data!);
  }
}
