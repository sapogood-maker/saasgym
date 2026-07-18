import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

import 'package:admin_web/app.dart';

/// Mesmo raciocínio do `_AdapterSemRede` de `widget_test.dart` — rejeita
/// toda requisição sem depender de rede real nem travar em timeout.
class _AdapterSemRede implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(requestOptions: options, reason: 'sem rede no teste de widget');
  }

  @override
  void close({bool force = false}) {}
}

class _TurmasApiVazia extends TurmasApi {
  _TurmasApiVazia() : super(Dio());

  @override
  Future<PaginatedResult<Turma>> list({String? search, UserStatus? status, int page = 1, int pageSize = 20}) async {
    return const PaginatedResult(items: [], total: 0, page: 1, pageSize: 20);
  }
}

class _ProfessoresApiVazia extends ProfessoresApi {
  _ProfessoresApiVazia() : super(Dio());

  @override
  Future<PaginatedResult<Professor>> list({
    String? search,
    UserStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const PaginatedResult(items: [], total: 0, page: 1, pageSize: 20);
  }
}

class _ModalidadesApiVazia extends ModalidadesApi {
  _ModalidadesApiVazia() : super(Dio());

  @override
  Future<PaginatedResult<Modalidade>> list({
    String? search,
    UserStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const PaginatedResult(items: [], total: 0, page: 1, pageSize: 20);
  }
}

Aula _aulaFixture({
  required String id,
  required String horaInicio,
  required List<String> alunosNomes,
  AulaStatus status = AulaStatus.agendada,
}) {
  final hoje = DateTime.now();
  return Aula(
    id: id,
    turmaId: 'turma-1',
    turmaNome: 'Turma Fixture',
    modalidadeId: 'mod-1',
    modalidadeNome: 'Musculação',
    recorrenciaId: 'recorrencia-1',
    data: DateTime(hoje.year, hoje.month, hoje.day),
    horaInicio: horaInicio,
    duracaoMinutos: 60,
    professorId: 'prof-1',
    professorNome: 'Lucas Lima',
    capacidadeMaxima: 10,
    status: status,
    motivoCancelamento: null,
    totalAlunos: alunosNomes.length,
    totalReposicoes: 0,
    alunosNomes: alunosNomes,
    local: null,
    createdAt: DateTime(2026, 1, 1),
  );
}

/// Fake de AulasApi.listCalendario() — ignora os filtros (não é o que este
/// teste verifica) e sempre devolve as mesmas aulas fixas, já com
/// `alunosNomes` populado (simula a resposta com `incluirAlunos: true`).
class _AulasApiComAlunos extends AulasApi {
  _AulasApiComAlunos() : super(Dio());

  static final aulaComMuitosAlunos = _aulaFixture(
    id: 'aula-muitos',
    horaInicio: '07:00',
    alunosNomes: const ['João Silva', 'Maria Souza', 'Carlos Pereira', 'Pedro Lima', 'Ana Costa'],
  );

  static final aulaSemAlunos = _aulaFixture(id: 'aula-vazia', horaInicio: '13:30', alunosNomes: const []);

  @override
  Future<PaginatedResult<Aula>> listCalendario({
    String? dataInicio,
    String? dataFim,
    String? turmaId,
    String? professorId,
    String? modalidadeId,
    AulaStatus? status,
    bool incluirAlunos = false,
    int page = 1,
    int pageSize = 100,
  }) async {
    return PaginatedResult(
      items: [aulaComMuitosAlunos, aulaSemAlunos],
      total: 2,
      page: 1,
      pageSize: pageSize,
    );
  }
}

void _usarViewportDesktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'Agenda operacional (docs/33): mostra nomes dos alunos em destaque, trunca quando muitos, sem vagas/capacidade',
    (WidgetTester tester) async {
      _usarViewportDesktop(tester);
      final container = ProviderContainer(
        overrides: [
          dashboardApiProvider.overrideWithValue(DashboardApi(Dio()..httpClientAdapter = _AdapterSemRede())),
          turmasApiProvider.overrideWithValue(_TurmasApiVazia()),
          professoresApiProvider.overrideWithValue(_ProfessoresApiVazia()),
          modalidadesApiProvider.overrideWithValue(_ModalidadesApiVazia()),
          aulasApiProvider.overrideWithValue(_AulasApiComAlunos()),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(authSessionProvider.notifier)
          .setSession(
            accessToken: 'token-fake',
            user: const AuthenticatedUser(
              id: 'user-1',
              nome: 'Ana Admin',
              email: 'ana@example.com',
              role: Role.academiaAdmin,
              academiaId: 'academia-1',
            ),
          );

      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const AdminApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calendário').first);
      await tester.pumpAndSettle();

      // Modo Dia — nomes em destaque, um por linha; "poucos -> todos".
      await tester.tap(find.text('Dia'));
      await tester.pumpAndSettle();

      expect(find.text('João Silva'), findsOneWidget);
      expect(find.text('Maria Souza'), findsOneWidget);
      expect(find.text('Carlos Pereira'), findsOneWidget);
      // "Muitos -> primeiros nomes + '+N alunos'": só 3 dos 5 aparecem.
      expect(find.text('Pedro Lima'), findsNothing);
      expect(find.text('Ana Costa'), findsNothing);
      expect(find.text('+2 alunos'), findsOneWidget);
      expect(find.textContaining('Musculação'), findsWidgets);
      expect(find.textContaining('Lucas Lima'), findsWidgets);

      // Aula sem alunos — estado vazio explícito, não uma lista em branco.
      expect(find.text('Nenhum aluno vinculado'), findsOneWidget);

      // Indicadores removidos desta sprint (docs/33): sem vagas/capacidade
      // nem resumo operacional agregado no topo.
      expect(find.textContaining('/10'), findsNothing);
      expect(find.textContaining('vagas'), findsNothing);
      expect(find.text('Resumo · '), findsNothing);

      // Abrir o modal repete a mesma informação sem nenhuma consulta nova
      // (os nomes já vieram na listagem) — clique na aula lotada.
      await tester.tap(find.text('João Silva'));
      await tester.pumpAndSettle();

      expect(find.text('Alunos'), findsWidgets);
      expect(find.text('+2 alunos'), findsWidgets);
      expect(find.textContaining('Musculação'), findsWidgets);
      expect(find.text('Cancelar aula'), findsOneWidget);
    },
  );
}
