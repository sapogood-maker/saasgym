import 'package:dio/dio.dart';

import 'evolucao_mensal_item.dart';
import 'resumo_financeiro.dart';

/// Painel Financeiro Gerencial — só leitura, sem CRUD (não estende
/// `CrudApi<T>`, mesmo motivo de `DashboardApi`: não há "um registro" pra
/// buscar/criar/editar, são indicadores agregados). Orquestrado no
/// backend (`DashboardFinanceiroService`) a partir de Mensalidades +
/// Lançamentos — o frontend só consome as 2 respostas já prontas
/// (docs/17, seção "MS5").
class DashboardFinanceiroApi {
  DashboardFinanceiroApi(this._dio);

  final Dio _dio;

  Future<ResumoFinanceiro> resumo({int? mes, int? ano}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/financeiro/dashboard',
      queryParameters: {'mes': ?mes, 'ano': ?ano},
    );
    return ResumoFinanceiro.fromJson(response.data!);
  }

  Future<List<EvolucaoMensalItem>> evolucao({int? mes, int? ano, int? meses}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/financeiro/dashboard/evolucao',
      queryParameters: {'mes': ?mes, 'ano': ?ano, 'meses': ?meses},
    );
    return (response.data!['meses'] as List)
        .cast<Map<String, dynamic>>()
        .map(EvolucaoMensalItem.fromJson)
        .toList();
  }
}
