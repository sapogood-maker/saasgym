import 'lancamento.dart';
import 'resumo_lancamentos.dart';
import '../common/crud_api.dart';
import '../common/lancamento_tipo.dart';
import '../common/paginated_result.dart';

/// `get`/`create`/`update`/`remove` herdados de `CrudApi<T>` cobrem 100%
/// do CRUD de Lançamento manual (endpoints equivalentes existem pros
/// quatro). Só `list()` não serve — filtra por `tipo`/competência/
/// intervalo de data, não `search`/status (Lancamento não tem status) —
/// daí `listLancamentos` como método próprio, mesmo motivo já documentado
/// em `MatriculasApi`/`MensalidadesApi`. `updateStatus()` continua
/// herdado mas não se aplica (sem campo de status genérico aqui).
/// `resumo()` não tem equivalente em `CrudApi<T>` — soma real do backend
/// pro Caixa (docs/17, seção "MS4").
class LancamentosApi extends CrudApi<Lancamento> {
  LancamentosApi(super.dio)
    : super(resourcePath: '/financeiro/lancamentos', fromJson: Lancamento.fromJson);

  Future<PaginatedResult<Lancamento>> listLancamentos({
    LancamentoTipo? tipo,
    int? mes,
    int? ano,
    String? dataInicio,
    String? dataFim,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      resourcePath,
      queryParameters: {
        if (tipo != null) 'tipo': tipo.wireValue,
        'mes': ?mes,
        'ano': ?ano,
        'dataInicio': ?dataInicio,
        'dataFim': ?dataFim,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return PaginatedResult.fromJson(response.data!, fromJson);
  }

  Future<ResumoLancamentos> resumo({int? mes, int? ano}) async {
    final response = await dio.get<Map<String, dynamic>>(
      '$resourcePath/resumo',
      queryParameters: {'mes': ?mes, 'ano': ?ano},
    );
    return ResumoLancamentos.fromJson(response.data!);
  }
}
