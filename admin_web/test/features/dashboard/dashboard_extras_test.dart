import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

import 'package:admin_web/features/dashboard/dashboard_extras.dart';

Mensalidade _mensalidade(DateTime vencimento) {
  return Mensalidade(
    id: 'm-${vencimento.toIso8601String()}',
    matriculaId: 'matricula-1',
    alunoId: 'aluno-1',
    alunoNome: 'Aluno Fixture',
    valor: 150,
    desconto: 0,
    multa: 0,
    valorFinal: 150,
    dataVencimento: vencimento,
    dataPagamento: null,
    status: MensalidadeStatus.pendente,
    atrasada: false,
    motivoCancelamento: null,
    formaPagamento: null,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

Aula _aula({required DateTime data, AulaStatus status = AulaStatus.agendada}) {
  return Aula(
    id: 'a-${data.toIso8601String()}-${status.wireValue}',
    turmaId: 'turma-1',
    turmaNome: 'Turma Fixture',
    modalidadeId: 'mod-1',
    modalidadeNome: 'Funcional',
    recorrenciaId: null,
    data: data,
    horaInicio: '07:00',
    duracaoMinutos: 60,
    professorId: 'prof-1',
    professorNome: 'Professor Fixture',
    capacidadeMaxima: 20,
    status: status,
    motivoCancelamento: null,
    totalAlunos: 5,
    totalReposicoes: 0,
    alunosNomes: const [],
    local: 'Sala 1',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

Matricula _matricula({required DateTime dataFimPrevista}) {
  return Matricula(
    id: 'mat-${dataFimPrevista.toIso8601String()}',
    alunoId: 'aluno-1',
    alunoNome: 'Aluno Fixture',
    alunoFotoUrl: null,
    planoId: 'plano-1',
    planoNome: 'Plano Fixture',
    createdByUserId: 'user-1',
    valor: 150,
    diaVencimento: 10,
    dataInicio: DateTime.utc(2026, 1, 1),
    dataFimPrevista: dataFimPrevista,
    dataFim: dataFimPrevista,
    status: MatriculaStatus.ativa,
    trancadoEm: null,
    trancamentoMotivo: null,
    motivoCancelamento: null,
    motivoCancelamentoDetalhe: null,
    matriculaAnteriorId: null,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  final hoje = DateTime.utc(2026, 7, 20);

  group('contarMensalidadesNoIntervalo', () {
    test('conta só as que caem no intervalo meio-aberto [inicio, fim)', () {
      final pendentes = [
        _mensalidade(DateTime.utc(2026, 7, 19)), // antes do intervalo
        _mensalidade(DateTime.utc(2026, 7, 20)), // exatamente hoje — dentro
        _mensalidade(DateTime.utc(2026, 7, 26)), // dentro dos 7 dias
        _mensalidade(DateTime.utc(2026, 7, 27)), // exatamente no limite — fora (exclusivo)
      ];
      final total = contarMensalidadesNoIntervalo(
        pendentes,
        hoje,
        hoje.add(const Duration(days: 7)),
      );
      expect(total, 2);
    });

    test('lista vazia retorna zero', () {
      expect(contarMensalidadesNoIntervalo([], hoje, hoje.add(const Duration(days: 1))), 0);
    });
  });

  group('contarAulasRealizadas', () {
    test('conta só aulas agendadas (não canceladas) com data antes de hoje', () {
      final aulas = [
        _aula(data: DateTime.utc(2026, 7, 10)), // realizada
        _aula(data: DateTime.utc(2026, 7, 15), status: AulaStatus.cancelada), // cancelada, não conta
        _aula(data: DateTime.utc(2026, 7, 20)), // hoje, ainda não "antes de hoje"
        _aula(data: DateTime.utc(2026, 7, 25)), // futura, não conta
      ];
      expect(contarAulasRealizadas(aulas, hoje), 1);
    });
  });

  group('contarMatriculasVencendo', () {
    test('conta matrículas com dataFimPrevista dentro da janela, hoje incluso', () {
      final ativas = [
        _matricula(dataFimPrevista: DateTime.utc(2026, 7, 19)), // ontem — fora
        _matricula(dataFimPrevista: DateTime.utc(2026, 7, 20)), // hoje — dentro
        _matricula(dataFimPrevista: DateTime.utc(2026, 7, 30)), // dentro de 15 dias
        _matricula(dataFimPrevista: DateTime.utc(2026, 8, 10)), // fora da janela
      ];
      expect(contarMatriculasVencendo(ativas, hoje, janelaDias: 15), 2);
    });
  });
}
