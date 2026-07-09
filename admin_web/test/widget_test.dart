import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

import 'package:admin_web/app.dart';

/// Adapter fake que rejeita toda requisição imediatamente (sem socket real,
/// sem timer pendente) — usado para que o teste de widget não dependa de um
/// backend rodando nem fique preso no `connectTimeout` do Dio.
class _AdapterSemRede implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'sem rede no teste de widget',
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Fake de AlunosApi.list() — sem depender de rede/backend, prova que a
/// tela de lista consome o resultado paginado e renderiza os itens.
class _AlunosApiComUmAluno extends AlunosApi {
  _AlunosApiComUmAluno() : super(Dio());

  @override
  Future<PaginatedResult<Aluno>> list({
    String? search,
    UserStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    return PaginatedResult(
      items: [
        Aluno(
          id: 'aluno-1',
          fotoUrl: null,
          nome: 'Maria Teste',
          cpf: '11144477735',
          rg: null,
          dataNascimento: DateTime(2000, 1, 31),
          sexo: Sexo.feminino,
          telefone: '11999999999',
          whatsapp: null,
          email: null,
          endereco: null,
          cidade: null,
          estado: null,
          cep: null,
          observacoes: null,
          status: UserStatus.ativo,
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
      total: 1,
      page: 1,
      pageSize: pageSize,
    );
  }
}

/// Fake de ProfessoresApi.list() — mesmo raciocínio de _AlunosApiComUmAluno.
class _ProfessoresApiComUmProfessor extends ProfessoresApi {
  _ProfessoresApiComUmProfessor() : super(Dio());

  @override
  Future<PaginatedResult<Professor>> list({
    String? search,
    UserStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    return PaginatedResult(
      items: [
        Professor(
          id: 'professor-1',
          fotoUrl: null,
          nome: 'João Treinador',
          cpf: '52998224725',
          telefone: '11988887777',
          email: null,
          especialidade: 'Musculação',
          observacoes: null,
          status: UserStatus.ativo,
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
      total: 1,
      page: 1,
      pageSize: pageSize,
    );
  }
}

void main() {
  testWidgets('sem sessão, redireciona para a tela de login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AdminApp()));
    await tester.pumpAndSettle();

    expect(find.text('Painel administrativo'), findsOneWidget);
    expect(find.text('Entrar'), findsWidgets);
  });

  testWidgets('com sessão ativa, mostra o shell com o dashboard', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        dashboardApiProvider.overrideWithValue(
          DashboardApi(Dio()..httpClientAdapter = _AdapterSemRede()),
        ),
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

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AdminApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alunos'), findsWidgets);
    expect(find.text('Professores'), findsWidgets);
    expect(find.text('Meu perfil'), findsWidgets);
    expect(find.text('Não foi possível carregar o dashboard.'), findsOneWidget);
  });

  testWidgets('lista de alunos renderiza os itens retornados pela API', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        dashboardApiProvider.overrideWithValue(
          DashboardApi(Dio()..httpClientAdapter = _AdapterSemRede()),
        ),
        alunosApiProvider.overrideWithValue(_AlunosApiComUmAluno()),
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

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AdminApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alunos').first);
    await tester.pumpAndSettle();

    expect(find.text('Maria Teste'), findsOneWidget);
    expect(find.textContaining('11144477735'), findsOneWidget);
  });

  testWidgets('lista de professores renderiza os itens retornados pela API', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        dashboardApiProvider.overrideWithValue(
          DashboardApi(Dio()..httpClientAdapter = _AdapterSemRede()),
        ),
        professoresApiProvider.overrideWithValue(
          _ProfessoresApiComUmProfessor(),
        ),
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

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AdminApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Professores').first);
    await tester.pumpAndSettle();

    expect(find.text('João Treinador'), findsOneWidget);
    expect(find.textContaining('Musculação'), findsOneWidget);
  });
}
