import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

/// Habilita o envio do cookie httpOnly de refresh em requisições
/// cross-origin (admin_web/student_web em portas diferentes do backend em
/// dev local) — sem isso, o navegador nunca envia o cookie e o refresh
/// automático do ApiClient nunca funciona de verdade.
void enableCredentials(Dio dio) {
  (dio.httpClientAdapter as BrowserHttpClientAdapter).withCredentials = true;
}
