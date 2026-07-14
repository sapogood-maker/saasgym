import 'mensalidade.dart';
import '../common/crud_api.dart';
import '../common/forma_pagamento.dart';
import '../common/mensalidade_status.dart';
import '../common/paginated_result.dart';

/// Resultado de [MensalidadesApi.gerar] — quantas mensalidades foram
/// criadas de fato e quantas matrículas já tinham mensalidade pro período
/// (geração é idempotente, ver `MensalidadesService.gerar` no backend).
class GerarMensalidadesResultado {
  const GerarMensalidadesResultado({required this.criadas, required this.totalPuladas});

  factory GerarMensalidadesResultado.fromJson(Map<String, dynamic> json) {
    return GerarMensalidadesResultado(
      criadas: (json['criadas'] as List)
          .cast<Map<String, dynamic>>()
          .map(Mensalidade.fromJson)
          .toList(),
      totalPuladas: json['totalPuladas'] as int,
    );
  }

  final List<Mensalidade> criadas;
  final int totalPuladas;
}

/// Mensalidade não nasce de um `create()` genérico — a única forma de
/// criar é `gerar()` (bulk, sob demanda, a partir das matrículas ativas do
/// mês — ver docs/17-modulo-3-financeiro-analise.md). `get`/`update`/
/// `remove` herdados de `CrudApi<T>` continuam valendo (endpoints
/// equivalentes existem); `list()`/`updateStatus()` não servem — mesmo
/// motivo já documentado em `MatriculasApi` (filtros/tipo de status
/// próprios, sem override válido em Dart) — daí `listMensalidades` como
/// método próprio e `marcarPaga`/`cancelar` dedicados (não é uma
/// transição de status genérica, tem payload/efeito colateral próprios —
/// `marcarPaga` gera um Lancamento).
class MensalidadesApi extends CrudApi<Mensalidade> {
  MensalidadesApi(super.dio)
    : super(resourcePath: '/financeiro/mensalidades', fromJson: Mensalidade.fromJson);

  Future<GerarMensalidadesResultado> gerar({int? mes, int? ano}) async {
    final response = await dio.post<Map<String, dynamic>>(
      '$resourcePath/gerar',
      data: {'mes': ?mes, 'ano': ?ano},
    );
    return GerarMensalidadesResultado.fromJson(response.data!);
  }

  Future<PaginatedResult<Mensalidade>> listMensalidades({
    String? search,
    String? matriculaId,
    String? alunoId,
    MensalidadeStatus? status,
    int? mes,
    int? ano,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      resourcePath,
      queryParameters: {
        'search': ?search,
        'matriculaId': ?matriculaId,
        'alunoId': ?alunoId,
        if (status != null) 'status': status.wireValue,
        'mes': ?mes,
        'ano': ?ano,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return PaginatedResult.fromJson(response.data!, fromJson);
  }

  Future<Mensalidade> marcarPaga(
    String id, {
    required FormaPagamento formaPagamento,
    String? dataPagamento,
  }) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '$resourcePath/$id/pagar',
      data: {'formaPagamento': formaPagamento.wireValue, 'dataPagamento': ?dataPagamento},
    );
    return fromJson(response.data!);
  }

  Future<Mensalidade> cancelar(String id, {String? motivo}) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '$resourcePath/$id/cancelar',
      data: {'motivo': ?motivo},
    );
    return fromJson(response.data!);
  }
}
