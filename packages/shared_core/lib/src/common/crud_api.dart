import 'package:dio/dio.dart';
import 'paginated_result.dart';
import 'user_status.dart';

/// Base genérica para o CRUD de qualquer entidade tenant-scoped que segue
/// o padrão consolidado por Aluno/Professor/Plano: `list` (paginado, busca
/// + filtro de status), `get`, `create`, `update`, `updateStatus`,
/// `remove` (soft delete). Terceira repetição idêntica confirmada — ver
/// decisão registrada na revisão arquitetural do Módulo 1.
///
/// **Deliberadamente sem `uploadFoto`** — não é universal (Plano não tem
/// foto, Matrícula não vai ter); cada subclasse que precisar declara o
/// próprio método usando [dio]/[resourcePath] herdados. Métodos extras
/// que só uma entidade tem (ex.: `Matricula.renovar`) também entram assim,
/// como método adicional na subclasse — a base nunca tenta prever tudo.
///
/// Exemplo:
/// ```dart
/// class PlanosApi extends CrudApi<Plano> {
///   PlanosApi(Dio dio) : super(dio, resourcePath: '/planos', fromJson: Plano.fromJson);
/// }
/// ```
abstract class CrudApi<T> {
  CrudApi(this.dio, {required this.resourcePath, required this.fromJson});

  final Dio dio;
  final String resourcePath;
  final T Function(Map<String, dynamic>) fromJson;

  Future<PaginatedResult<T>> list({
    String? search,
    UserStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      resourcePath,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null) 'status': status.wireValue,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return PaginatedResult.fromJson(response.data!, fromJson);
  }

  Future<T> get(String id) async {
    final response = await dio.get<Map<String, dynamic>>('$resourcePath/$id');
    return fromJson(response.data!);
  }

  Future<T> create(Map<String, dynamic> dados) async {
    final response = await dio.post<Map<String, dynamic>>(resourcePath, data: dados);
    return fromJson(response.data!);
  }

  Future<T> update(String id, Map<String, dynamic> dados) async {
    final response = await dio.patch<Map<String, dynamic>>('$resourcePath/$id', data: dados);
    return fromJson(response.data!);
  }

  Future<T> updateStatus(String id, UserStatus status, {String? motivo}) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '$resourcePath/$id/status',
      data: {'status': status.wireValue, 'motivo': ?motivo},
    );
    return fromJson(response.data!);
  }

  Future<void> remove(String id) async {
    await dio.delete<void>('$resourcePath/$id');
  }
}
