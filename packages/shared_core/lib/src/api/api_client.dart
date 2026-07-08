import 'package:dio/dio.dart';

/// Cliente HTTP único usado por admin_web e student_web para falar com a API
/// do SaaSGym, garantindo que os dois frontends nunca divirjam do contrato
/// da API (base URL, headers, tratamento de erros).
///
/// O fluxo de refresh automático (interceptor que chama `/auth/refresh` em
/// um 401 e repete a requisição original) é adicionado no Sprint 1, junto
/// com o módulo `auth` do backend.
class ApiClient {
  ApiClient({required String baseUrl, String? Function()? getAccessToken})
      : _getAccessToken = getAccessToken,
        dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _getAccessToken?.call();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  final String? Function()? _getAccessToken;
}
