import 'package:shared_core/shared_core.dart';

/// Combina a data (dia civil) da Aula com o horário de início (`"HH:mm"`)
/// num único `DateTime` local — mesma convenção de calendário já usada no
/// resto da Agenda (sem fuso horário dedicado, docs/18).
DateTime dataHoraInicioDaAula(Aula aula) {
  final partes = aula.horaInicio.split(':');
  final hora = int.parse(partes[0]);
  final minuto = int.parse(partes[1]);
  return DateTime(aula.data.year, aula.data.month, aula.data.day, hora, minuto);
}

/// Uma Aula passa a aceitar frequência assim que ela **começa** — não
/// precisa esperar ela terminar, nem o dia seguinte.
///
/// Bug corrigido na Sprint 31 (Release Blockers v1.0): a versão anterior
/// só comparava a data (`aula.data.isBefore(hoje)`), então uma aula de
/// hoje nunca era "realizada" antes de amanhã — o professor não conseguia
/// marcar presença no mesmo dia da própria aula, o cenário mais comum de
/// uso. Agora considera `horaInicio`: basta a aula já ter começado.
///
/// `agora` é injetável só para teste determinístico (ver
/// `test/features/agenda/aula_frequencia_util_test.dart`); em produção é
/// sempre `DateTime.now()`.
bool aulaPodeRegistrarFrequencia(Aula aula, {DateTime? agora}) {
  if (aula.status != AulaStatus.agendada) {
    return false;
  }
  final referencia = agora ?? DateTime.now();
  return !referencia.isBefore(dataHoraInicioDaAula(aula));
}
