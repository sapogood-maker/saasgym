import 'package:dio/dio.dart';

/// Stub para plataformas não-web (aqui, só o alvo VM usado por `flutter
/// test` por padrão — este projeto não tem app mobile/desktop). Sem isso,
/// importar dio/browser.dart incondicionalmente quebra a compilação dos
/// testes, que rodam na VM do Dart, não num navegador de verdade.
void enableCredentials(Dio dio) {}
