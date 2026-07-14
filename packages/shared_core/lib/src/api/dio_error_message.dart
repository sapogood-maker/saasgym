import 'package:dio/dio.dart';

/// Extrai uma mensagem de erro amigável de uma resposta de erro da API —
/// mesmo formato usado em todo o backend (`{message: string | string[]}`,
/// class-validator quando há múltiplos erros de campo). Antes duplicada
/// (corpo idêntico) em 15 telas do admin_web; centralizada aqui na Sprint
/// de Consolidação do Módulo 4.
String mensagemErroApi(DioException e, {String fallback = 'Não foi possível concluir a operação.'}) {
  final data = e.response?.data;
  if (data is Map && data['message'] != null) {
    final message = data['message'];
    return message is List ? message.join(', ') : message.toString();
  }
  return fallback;
}
