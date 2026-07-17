import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

  static final _maria = Aluno(
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
  );

  @override
  Future<PaginatedResult<Aluno>> list({
    String? search,
    UserStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    return PaginatedResult(items: [_maria], total: 1, page: 1, pageSize: pageSize);
  }

  @override
  Future<Aluno> get(String id) async => _maria;
}

/// Fake de ProfessoresApi.list() — mesmo raciocínio de _AlunosApiComUmAluno.
class _ProfessoresApiComUmProfessor extends ProfessoresApi {
  _ProfessoresApiComUmProfessor() : super(Dio());

  static final _joao = Professor(
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
  );

  @override
  Future<PaginatedResult<Professor>> list({
    String? search,
    UserStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    return PaginatedResult(items: [_joao], total: 1, page: 1, pageSize: pageSize);
  }

  @override
  Future<Professor> get(String id) async => _joao;
}

/// Fake de PlanosApi.list() — mesmo raciocínio de _AlunosApiComUmAluno.
/// Primeira API construída direto sobre `CrudApi`.
class _PlanosApiComUmPlano extends PlanosApi {
  _PlanosApiComUmPlano() : super(Dio());

  static final _musculacao = Plano(
    id: 'plano-1',
    nome: 'Plano Musculação',
    descricao: null,
    periodicidade: Periodicidade.mensal,
    valor: 129.9,
    quantidadeAulas: null,
    ordem: null,
    status: UserStatus.ativo,
    createdAt: DateTime(2026, 1, 1),
  );

  @override
  Future<PaginatedResult<Plano>> list({
    String? search,
    UserStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    return PaginatedResult(
      items: [_musculacao],
      total: 1,
      page: 1,
      pageSize: pageSize,
    );
  }

  @override
  Future<Plano> get(String id) async => _musculacao;
}

/// Fake de AlunosApi.list() — usado só pra abrir a lista antes de navegar
/// pro formulário; retorna vazio de propósito (o teste não depende do
/// conteúdo da lista, só precisa que a tela carregue sem erro).
class _AlunosApiVazia extends AlunosApi {
  _AlunosApiVazia() : super(Dio());

  @override
  Future<PaginatedResult<Aluno>> list({
    String? search,
    UserStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const PaginatedResult(items: [], total: 0, page: 1, pageSize: 20);
  }
}

/// Fakes "vazios" pras 3 seções embutidas no Detalhe do Aluno que passaram
/// a consumir API real na Sprint de Correção de Placeholders (Matrículas/
/// Financeiro/Frequência) — sem override, `apiClientProvider` tentaria
/// bater num backend real inexistente no teste de widget.
class _MatriculasApiVazia extends MatriculasApi {
  _MatriculasApiVazia() : super(Dio());

  @override
  Future<PaginatedResult<Matricula>> listMatriculas({
    String? search,
    String? alunoId,
    String? planoId,
    MatriculaStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const PaginatedResult(items: [], total: 0, page: 1, pageSize: 20);
  }
}

class _MensalidadesApiVazia extends MensalidadesApi {
  _MensalidadesApiVazia() : super(Dio());

  @override
  Future<PaginatedResult<Mensalidade>> listMensalidades({
    String? search,
    String? matriculaId,
    String? alunoId,
    MensalidadeStatus? status,
    int? mes,
    int? ano,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const PaginatedResult(items: [], total: 0, page: 1, pageSize: 20);
  }
}

class _AulaAlunosApiVazia extends AulaAlunosApi {
  _AulaAlunosApiVazia() : super(Dio());

  @override
  Future<PaginatedResult<FrequenciaAluno>> listPorAluno(
    String alunoId, {
    String? dataInicio,
    String? dataFim,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const PaginatedResult(items: [], total: 0, page: 1, pageSize: 20);
  }
}

/// Fake de ProfessoresApi.list() — mesmo raciocínio de _AlunosApiVazia.
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

/// Fake de PlanosApi.list() — mesmo raciocínio de _AlunosApiVazia.
class _PlanosApiVazia extends PlanosApi {
  _PlanosApiVazia() : super(Dio());

  @override
  Future<PaginatedResult<Plano>> list({
    String? search,
    UserStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const PaginatedResult(items: [], total: 0, page: 1, pageSize: 20);
  }
}

/// Desktop explícito pra qualquer teste que não seja sobre mobile/tablet —
/// sem isso, o tamanho padrão da superfície de teste cai na faixa de
/// tablet (600-1024px), que a partir da Sprint 31 (Release Blockers v1.0)
/// passou a usar o mesmo layout de toque do celular (Drawer) — correto
/// pro produto (docs/30, achado Médio), mas quebra testes que esperam a
/// sidebar fixa sempre visível sem abrir o Drawer primeiro.
void _usarViewportDesktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
    _usarViewportDesktop(tester);
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

    // A sidebar cresceu bastante desde que este teste foi escrito (agora
    // cobre Cadastros/Agenda/Financeiro/Conta) — "Meu perfil" (seção
    // "Conta") não cabe mais na viewport padrão de teste e o ListView só
    // constrói o que está visível. Rola até revelá-lo antes de checar.
    await tester.scrollUntilVisible(
      find.text('Meu perfil'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Meu perfil'), findsWidgets);
    expect(find.text('Não foi possível carregar o dashboard.'), findsOneWidget);
  });

  testWidgets('no mobile, tocar num item da sidebar fecha o Drawer', (
    WidgetTester tester,
  ) async {
    // Regressão: onDestinationSelected só navegava (context.go), sem
    // fechar o Drawer — a tela nova ficava escondida atrás dele até o
    // usuário tocar fora manualmente.
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);

    await tester.tap(find.text('Alunos').first);
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('no tablet (768px), o shell usa Drawer em vez da sidebar fixa de desktop', (
    WidgetTester tester,
  ) async {
    // Sprint 31 (Release Blockers v1.0), docs/30 achado Médio: antes só
    // `isMobile` (<600px) usava Drawer — um tablet em retrato (600-1024px)
    // caía no mesmo layout de sidebar fixa do desktop, espremendo o
    // conteúdo. `AppShell` passou a usar `isTouch` (mobile OU tablet).
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    // Sidebar não é fixa — só aparece ao abrir o menu.
    expect(find.text('Alunos'), findsNothing);
    expect(find.byTooltip('Menu'), findsOneWidget);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text('Alunos'), findsOneWidget);
  });

  testWidgets('lista de alunos renderiza os itens retornados pela API', (
    WidgetTester tester,
  ) async {
    _usarViewportDesktop(tester);
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

  testWidgets('painel de detalhe do aluno mostra dados reais e seções sem dado como empty state', (
    WidgetTester tester,
  ) async {
    _usarViewportDesktop(tester);
    final container = ProviderContainer(
      overrides: [
        dashboardApiProvider.overrideWithValue(
          DashboardApi(Dio()..httpClientAdapter = _AdapterSemRede()),
        ),
        alunosApiProvider.overrideWithValue(_AlunosApiComUmAluno()),
        matriculasApiProvider.overrideWithValue(_MatriculasApiVazia()),
        mensalidadesApiProvider.overrideWithValue(_MensalidadesApiVazia()),
        aulaAlunosApiProvider.overrideWithValue(_AulaAlunosApiVazia()),
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
    await tester.tap(find.text('Maria Teste'));
    await tester.pumpAndSettle();

    // Dados reais carregados via AlunosApi.get() — aparece no cabeçalho do
    // painel e de novo como valor em "Dados pessoais".
    expect(find.text('Maria Teste'), findsWidgets);
    expect(find.text('Ativo'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Remover'), findsOneWidget);

    // Matrículas/Financeiro/Frequência consomem API real desde a Sprint de
    // Correção de Placeholders — sem nenhum registro, mostram empty state
    // de verdade, nunca mais a tag "MÓDULO N".
    expect(find.text('Matrículas'), findsOneWidget);
    expect(find.text('Nenhuma matrícula encontrada.'), findsOneWidget);
    expect(find.text('Nenhuma mensalidade encontrada.'), findsOneWidget);
    expect(find.text('Nenhuma presença registrada.'), findsOneWidget);
  });

  testWidgets('lista de professores renderiza os itens retornados pela API', (
    WidgetTester tester,
  ) async {
    _usarViewportDesktop(tester);
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

  testWidgets('lista de planos renderiza os itens retornados pela API', (
    WidgetTester tester,
  ) async {
    _usarViewportDesktop(tester);
    final container = ProviderContainer(
      overrides: [
        dashboardApiProvider.overrideWithValue(
          DashboardApi(Dio()..httpClientAdapter = _AdapterSemRede()),
        ),
        planosApiProvider.overrideWithValue(_PlanosApiComUmPlano()),
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

    await tester.tap(find.text('Planos').first);
    await tester.pumpAndSettle();

    expect(find.text('Plano Musculação'), findsOneWidget);
    // "Mensal" sozinho hoje casa também com o item "Mensalidades" da
    // sidebar (Financeiro) — mira o texto completo da linha do plano.
    expect(find.textContaining('Mensal · Aulas ilimitadas'), findsOneWidget);
    expect(find.textContaining('R\$'), findsOneWidget);
  });

  testWidgets('painel de detalhe do plano mostra dados reais e seção sem dado como empty state', (
    WidgetTester tester,
  ) async {
    _usarViewportDesktop(tester);
    final container = ProviderContainer(
      overrides: [
        dashboardApiProvider.overrideWithValue(
          DashboardApi(Dio()..httpClientAdapter = _AdapterSemRede()),
        ),
        planosApiProvider.overrideWithValue(_PlanosApiComUmPlano()),
        matriculasApiProvider.overrideWithValue(_MatriculasApiVazia()),
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

    await tester.tap(find.text('Planos').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plano Musculação'));
    await tester.pumpAndSettle();

    // Dados reais carregados via PlanosApi.get() — aparece no cabeçalho do
    // painel e de novo como valor em "Dados do plano".
    expect(find.text('Plano Musculação'), findsWidgets);
    expect(find.text('Ativo'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Remover'), findsOneWidget);

    // "Alunos matriculados" consome API real desde a Sprint de Correção de
    // Placeholders — sem nenhuma matrícula, mostra empty state de verdade.
    // "Financeiro" por plano ainda não tem agregação no backend — continua
    // sendo o único placeholder remanescente nesta tela (docs/29).
    expect(find.text('Alunos matriculados'), findsOneWidget);
    expect(find.text('Nenhum aluno matriculado.'), findsOneWidget);
    expect(find.text('MÓDULO 3 · FINANCEIRO'), findsOneWidget);
  });

  testWidgets('formulário de plano mostra erro de validação em todos os campos obrigatórios', (
    WidgetTester tester,
  ) async {
    _usarViewportDesktop(tester);
    final container = ProviderContainer(
      overrides: [
        dashboardApiProvider.overrideWithValue(
          DashboardApi(Dio()..httpClientAdapter = _AdapterSemRede()),
        ),
        planosApiProvider.overrideWithValue(_PlanosApiVazia()),
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

    await tester.tap(find.text('Planos').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo plano'));
    await tester.pumpAndSettle();

    expect(find.text('Novo plano'), findsWidgets);

    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pump();

    expect(find.text('Informe o nome'), findsOneWidget);
    expect(find.text('Informe a periodicidade'), findsOneWidget);
    expect(find.text('Informe o valor'), findsOneWidget);
  });

  testWidgets('painel de detalhe do professor mostra dados reais e seções futuras como placeholder', (
    WidgetTester tester,
  ) async {
    _usarViewportDesktop(tester);
    final container = ProviderContainer(
      overrides: [
        dashboardApiProvider.overrideWithValue(
          DashboardApi(Dio()..httpClientAdapter = _AdapterSemRede()),
        ),
        professoresApiProvider.overrideWithValue(_ProfessoresApiComUmProfessor()),
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
    await tester.tap(find.text('João Treinador'));
    await tester.pumpAndSettle();

    expect(find.text('João Treinador'), findsWidgets);
    expect(find.text('Ativo'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Remover'), findsOneWidget);

    // Seções futuras diferentes das de Aluno — Turmas/Financeiro fazem
    // sentido pra um professor, Avaliações/Frequência/Treinos não.
    expect(find.text('Turmas'), findsOneWidget);
    expect(find.text('MÓDULO 4 · MS6'), findsOneWidget);
    expect(find.text('MÓDULO 3 · FINANCEIRO'), findsOneWidget);
  });

  testWidgets('formulário de professor mostra erro de validação em todos os campos obrigatórios', (
    WidgetTester tester,
  ) async {
    _usarViewportDesktop(tester);
    final container = ProviderContainer(
      overrides: [
        dashboardApiProvider.overrideWithValue(
          DashboardApi(Dio()..httpClientAdapter = _AdapterSemRede()),
        ),
        professoresApiProvider.overrideWithValue(_ProfessoresApiVazia()),
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
    await tester.tap(find.text('Novo professor'));
    await tester.pumpAndSettle();

    expect(find.text('Novo professor'), findsWidgets);

    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pump();

    expect(find.text('Informe o nome'), findsOneWidget);
    expect(find.text('Informe o CPF'), findsOneWidget);
    expect(find.text('Informe o telefone'), findsOneWidget);
  });

  testWidgets('formulário de aluno mostra erro de validação em todos os campos obrigatórios', (
    WidgetTester tester,
  ) async {
    _usarViewportDesktop(tester);
    final container = ProviderContainer(
      overrides: [
        dashboardApiProvider.overrideWithValue(
          DashboardApi(Dio()..httpClientAdapter = _AdapterSemRede()),
        ),
        alunosApiProvider.overrideWithValue(_AlunosApiVazia()),
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
    await tester.tap(find.text('Novo aluno'));
    await tester.pumpAndSettle();

    expect(find.text('Novo aluno'), findsWidgets);

    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pump();

    // Mesmo padrão de erro em todos os campos obrigatórios — nome, CPF,
    // telefone (AppTextField), data de nascimento (AppDateField) e sexo
    // (AppSelect) usam o mesmo chassi de validação do MS1.
    expect(find.text('Informe o nome'), findsOneWidget);
    expect(find.text('Informe o CPF'), findsOneWidget);
    expect(find.text('Informe o telefone'), findsOneWidget);
    expect(find.text('Informe a data de nascimento'), findsOneWidget);
    expect(find.text('Informe o sexo'), findsOneWidget);
  });
}
