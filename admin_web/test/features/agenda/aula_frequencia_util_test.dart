import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

import 'package:admin_web/features/agenda/aula_frequencia_util.dart';

/// Aula mínima pra teste — só os campos que `aulaPodeRegistrarFrequencia`
/// de fato usa (`status`, `data`, `horaInicio`) importam; o resto é
/// preenchido só porque o construtor exige.
Aula _aula({
  required DateTime data,
  required String horaInicio,
  AulaStatus status = AulaStatus.agendada,
}) {
  return Aula(
    id: 'aula-1',
    turmaId: 'turma-1',
    turmaNome: 'Funcional Manhã',
    modalidadeId: 'modalidade-1',
    modalidadeNome: 'Funcional',
    recorrenciaId: 'recorrencia-1',
    data: data,
    horaInicio: horaInicio,
    duracaoMinutos: 60,
    professorId: 'professor-1',
    professorNome: 'Prof. Ana',
    capacidadeMaxima: 15,
    status: status,
    motivoCancelamento: null,
    totalAlunos: 5,
    totalReposicoes: 0,
    alunosNomes: const [],
    local: null,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  // Referência fixa: quinta-feira, 16/07/2026, 08:00 — a aula é sempre das
  // 07:00 às 08:00 (duracaoMinutos: 60), então "agora" cai bem no meio ou
  // logo depois, dependendo do cenário.
  final agora = DateTime(2026, 7, 16, 8, 0);

  group('aulaPodeRegistrarFrequencia', () {
    test('aula iniciada exatamente agora -> permite registrar', () {
      final aula = _aula(data: DateTime(2026, 7, 16), horaInicio: '08:00');
      expect(aulaPodeRegistrarFrequencia(aula, agora: agora), isTrue);
    });

    test('aula em andamento (começou há 30min, ainda dentro da duração) -> permite registrar', () {
      final aula = _aula(data: DateTime(2026, 7, 16), horaInicio: '07:30');
      expect(aulaPodeRegistrarFrequencia(aula, agora: agora), isTrue);
    });

    test('aula encerrada hoje (começou de manhã cedo, já bem passada) -> permite registrar', () {
      final aula = _aula(data: DateTime(2026, 7, 16), horaInicio: '06:00');
      expect(aulaPodeRegistrarFrequencia(aula, agora: agora), isTrue);
    });

    test('aula de ontem -> permite registrar (nunca expira)', () {
      final aula = _aula(data: DateTime(2026, 7, 15), horaInicio: '07:00');
      expect(aulaPodeRegistrarFrequencia(aula, agora: agora), isTrue);
    });

    test('aula futura (mais tarde hoje, ainda não começou) -> não permite registrar', () {
      final aula = _aula(data: DateTime(2026, 7, 16), horaInicio: '09:00');
      expect(aulaPodeRegistrarFrequencia(aula, agora: agora), isFalse);
    });

    test('aula futura (amanhã) -> não permite registrar', () {
      final aula = _aula(data: DateTime(2026, 7, 17), horaInicio: '07:00');
      expect(aulaPodeRegistrarFrequencia(aula, agora: agora), isFalse);
    });

    test('aula cancelada, mesmo já iniciada -> não permite registrar', () {
      final aula = _aula(
        data: DateTime(2026, 7, 16),
        horaInicio: '07:00',
        status: AulaStatus.cancelada,
      );
      expect(aulaPodeRegistrarFrequencia(aula, agora: agora), isFalse);
    });
  });

  group('dataHoraInicioDaAula', () {
    test('combina a data civil da aula com o horário de início', () {
      final aula = _aula(data: DateTime(2026, 7, 16), horaInicio: '07:05');
      expect(dataHoraInicioDaAula(aula), DateTime(2026, 7, 16, 7, 5));
    });
  });
}
