import 'package:dio/dio.dart';

import 'credentials_config_stub.dart'
    if (dart.library.js_interop) 'credentials_config_web.dart'
    if (dart.library.html) 'credentials_config_web.dart'
    as credentials_config;

/// Cliente HTTP único usado por admin_web e student_web para falar com a API
/// do SaaSGym, garantindo que os dois frontends nunca divirjam do contrato
/// da API (base URL, headers, tratamento de erros).
///
/// Refresh automático: numa resposta 401 (exceto para /auth/login e
/// /auth/refresh, para nunca entrar em loop), chama /auth/refresh uma vez —
/// o cookie httpOnly de refresh é enviado automaticamente pelo navegador
/// (withCredentials) — e reexecuta a requisição original com o novo access
/// token. Requisições concorrentes que falham ao mesmo tempo compartilham a
/// mesma chamada de refresh (nunca disparam duas em paralelo).
///
/// Este projeto só tem alvo Flutter Web (admin_web/student_web) — mas
/// `flutter test` roda na VM do Dart, não num navegador, por padrão; o
/// import condicional evita quebrar a compilação dos testes (mesmo padrão
/// que o próprio pacote dio usa internamente para o adapter de browser).
class ApiClient {
  ApiClient({
    required String baseUrl,
    String? Function()? getAccessToken,
    void Function(String accessToken)? onTokenRefreshed,
    void Function()? onRefreshFailed,
  }) : _getAccessToken = getAccessToken,
       _onTokenRefreshed = onTokenRefreshed,
       _onRefreshFailed = onRefreshFailed,
       dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 10),
         ),
       ) {
    credentials_config.enableCredentials(dio);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _getAccessToken?.call();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final path = error.requestOptions.path;
          final isAuthEndpoint =
              path.contains('/auth/login') || path.contains('/auth/refresh');
          final jaTentouDeNovo =
              error.requestOptions.extra['jaTentouRefresh'] == true;

          if (error.response?.statusCode != 401 ||
              isAuthEndpoint ||
              jaTentouDeNovo) {
            handler.next(error);
            return;
          }

          try {
            final novoToken = await _renovarAccessToken();
            final options = error.requestOptions
              ..extra['jaTentouRefresh'] = true
              ..headers['Authorization'] = 'Bearer $novoToken';
            final response = await dio.fetch(options);
            handler.resolve(response);
          } catch (_) {
            _onRefreshFailed?.call();
            handler.next(error);
          }
        },
      ),
    );
  }

  final Dio dio;
  final String? Function()? _getAccessToken;
  final void Function(String accessToken)? _onTokenRefreshed;
  final void Function()? _onRefreshFailed;

  Future<String>? _refreshEmAndamento;

  Future<String> _renovarAccessToken() {
    return _refreshEmAndamento ??= _executarRefresh().whenComplete(() {
      _refreshEmAndamento = null;
    });
  }

  Future<String> _executarRefresh() async {
    final response = await dio.post<Map<String, dynamic>>('/auth/refresh');
    final novoToken = response.data!['accessToken'] as String;
    _onTokenRefreshed?.call(novoToken);
    return novoToken;
  }
}
