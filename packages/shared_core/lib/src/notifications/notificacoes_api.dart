import 'package:dio/dio.dart';

import 'notificacao.dart';

/// API própria — **não** estende `CrudApi<T>`: "minhas notificações" não é
/// uma coleção CRUD (sem `create`/`remove` — nasce só via `NotificationProvider`
/// no backend), e o formato paginado tem o campo extra `naoLidas`.
class NotificacoesApi {
  NotificacoesApi(this._dio);

  final Dio _dio;

  Future<NotificacoesPaginadas> list({int page = 1, int pageSize = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/notificacoes',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return NotificacoesPaginadas.fromJson(response.data!);
  }

  Future<Notificacao> marcarComoLida(String id) async {
    final response = await _dio.patch<Map<String, dynamic>>('/notificacoes/$id/lida');
    return Notificacao.fromJson(response.data!);
  }
}
