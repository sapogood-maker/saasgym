import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

import 'package:admin_web/app.dart';

/// PNG 1x1 transparente válido — ver mesmo comentário em
/// aluno_form_duplicidade_test.dart.
final _pngUmPixel = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Mesmo cenário de `aluno_form_duplicidade_test.dart`, pro Professor
/// (docs/30 — o mesmo achado cobre os dois formulários).
class _ProfessoresApiCriaEFalhaNaFoto extends ProfessoresApi {
  _ProfessoresApiCriaEFalhaNaFoto() : super(Dio());

  int createCalls = 0;
  int updateCalls = 0;
  int uploadFotoCalls = 0;

  static final _criado = Professor(
    id: 'professor-novo-1',
    fotoUrl: null,
    nome: 'Novo Professor Teste',
    cpf: '52998224725',
    telefone: '11988887777',
    email: null,
    especialidade: null,
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
    return PaginatedResult(items: const [], total: 0, page: 1, pageSize: pageSize);
  }

  @override
  Future<Professor> create(Map<String, dynamic> dados) async {
    createCalls++;
    return _criado;
  }

  @override
  Future<Professor> update(String id, Map<String, dynamic> dados) async {
    updateCalls++;
    expect(id, _criado.id, reason: 'retry deve atualizar o mesmo professor recém-criado, não outro');
    return _criado;
  }

  @override
  Future<Professor> uploadFoto(String id, {required Uint8List bytes, required String filename}) async {
    uploadFotoCalls++;
    if (uploadFotoCalls == 1) {
      throw DioException(
        requestOptions: RequestOptions(path: '/professores/$id/foto'),
        response: Response(
          requestOptions: RequestOptions(path: '/professores/$id/foto'),
          statusCode: 500,
          data: {'message': 'Falha simulada de rede'},
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return _criado;
  }
}

class _AdapterSemRede implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(requestOptions: options, reason: 'sem rede no teste de widget');
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets(
    'professor: falha no upload de foto após criar não duplica o cadastro numa nova tentativa',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final professoresApiFake = _ProfessoresApiCriaEFalhaNaFoto();
      final container = ProviderContainer(
        overrides: [
          dashboardApiProvider.overrideWithValue(
            DashboardApi(Dio()..httpClientAdapter = _AdapterSemRede()),
          ),
          professoresApiProvider.overrideWithValue(professoresApiFake),
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

      await tester.tap(find.text('Professores').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Novo professor'));
      await tester.pumpAndSettle();

      // Professor: Nome=0, CPF=1, Telefone=2 (sem RG entre CPF e Telefone,
      // diferente de Aluno).
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Novo Professor Teste');
      await tester.enterText(textFields.at(1), '52998224725');
      await tester.enterText(textFields.at(2), '11988887777');
      await tester.pump();

      final avatarPicker = tester.widget<AppAvatarPicker>(find.byType(AppAvatarPicker));
      avatarPicker.onPicked!((bytes: _pngUmPixel, filename: 'foto.png'));
      await tester.pump();

      // --- Primeira tentativa: create() ok, uploadFoto() falha ---
      await tester.ensureVisible(find.text('Salvar'));
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(professoresApiFake.createCalls, 1);
      expect(professoresApiFake.updateCalls, 0);
      expect(professoresApiFake.uploadFotoCalls, 1);
      expect(
        find.textContaining('Os dados foram salvos, mas a foto não pôde ser enviada'),
        findsOneWidget,
      );
      expect(find.text('Novo professor'), findsWidgets);

      // --- Segunda tentativa: deve usar update(), nunca um 2º create() ---
      await tester.ensureVisible(find.text('Salvar'));
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(professoresApiFake.createCalls, 1, reason: 'nunca deve criar um segundo professor');
      expect(professoresApiFake.updateCalls, 1);
      expect(professoresApiFake.uploadFotoCalls, 2);
    },
  );
}
