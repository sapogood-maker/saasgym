import 'package:dio/dio.dart';

import '../financeiro/evolucao_mensal_item.dart';
import 'relatorio_alunos_mensal.dart';
import 'relatorio_resumo.dart';

/// Só leitura, sem CRUD (mesmo motivo de `DashboardFinanceiroApi`) — o
/// backend (`RelatoriosService`) orquestra Financeiro/Matrículas/Aluno, o
/// frontend só consome. `receita()` reaproveita `EvolucaoMensalItem`:
/// `/relatorios/receita` delega pro mesmo `DashboardFinanceiroService.evolucao()`
/// do Painel Financeiro, é literalmente a mesma forma de resposta.
class RelatoriosApi {
  RelatoriosApi(this._dio);

  final Dio _dio;

  Future<List<EvolucaoMensalItem>> receita({int? mes, int? ano, int? meses}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/relatorios/receita',
      queryParameters: {'mes': ?mes, 'ano': ?ano, 'meses': ?meses},
    );
    return (response.data!['meses'] as List)
        .cast<Map<String, dynamic>>()
        .map(EvolucaoMensalItem.fromJson)
        .toList();
  }

  Future<List<RelatorioAlunosMensalItem>> alunos({int? mes, int? ano, int? meses}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/relatorios/alunos',
      queryParameters: {'mes': ?mes, 'ano': ?ano, 'meses': ?meses},
    );
    return (response.data!['meses'] as List)
        .cast<Map<String, dynamic>>()
        .map(RelatorioAlunosMensalItem.fromJson)
        .toList();
  }

  Future<RelatorioResumo> resumo({int? meses}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/relatorios/resumo',
      queryParameters: {'meses': ?meses},
    );
    return RelatorioResumo.fromJson(response.data!);
  }
}
