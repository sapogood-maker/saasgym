import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

import 'package:admin_web/app.dart';

/// PNG 1x1 transparente válido — `AppAvatarPicker` usa `MemoryImage` pra
/// pré-visualizar os bytes escolhidos, então precisam decodificar de
/// verdade (bytes arbitrários fazem o teste falhar por um erro assíncrono
/// de decodificação de imagem, sem relação nenhuma com o que este teste
/// quer provar).
final _pngUmPixel = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Reproduz exatamente o cenário do achado "risco de duplicidade no upload
/// de foto" (docs/30): `create()` funciona, `uploadFoto()` falha na
/// primeira tentativa — o teste prova que uma segunda tentativa de salvar
/// usa `update()` (nunca um segundo `create()`) e que a foto é reenviada
/// com sucesso.
class _AlunosApiCriaEFalhaNaFoto extends AlunosApi {
  _AlunosApiCriaEFalhaNaFoto() : super(Dio());

  int createCalls = 0;
  int updateCalls = 0;
  int uploadFotoCalls = 0;

  static final _criado = Aluno(
    id: 'aluno-novo-1',
    fotoUrl: null,
    nome: 'Novo Aluno Teste',
    cpf: '11144477735',
    rg: null,
    dataNascimento: DateTime(2000, 1, 31),
    sexo: Sexo.masculino,
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
    return PaginatedResult(items: const [], total: 0, page: 1, pageSize: pageSize);
  }

  @override
  Future<Aluno> create(Map<String, dynamic> dados) async {
    createCalls++;
    return _criado;
  }

  @override
  Future<Aluno> update(String id, Map<String, dynamic> dados) async {
    updateCalls++;
    expect(id, _criado.id, reason: 'retry deve atualizar o mesmo aluno recém-criado, não outro');
    return _criado;
  }

  @override
  Future<Aluno> uploadFoto(String id, {required Uint8List bytes, required String filename}) async {
    uploadFotoCalls++;
    if (uploadFotoCalls == 1) {
      throw DioException(
        requestOptions: RequestOptions(path: '/alunos/$id/foto'),
        response: Response(
          requestOptions: RequestOptions(path: '/alunos/$id/foto'),
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
    'aluno: falha no upload de foto após criar não duplica o cadastro numa nova tentativa',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final alunosApiFake = _AlunosApiCriaEFalhaNaFoto();
      final container = ProviderContainer(
        overrides: [
          dashboardApiProvider.overrideWithValue(
            DashboardApi(Dio()..httpClientAdapter = _AdapterSemRede()),
          ),
          alunosApiProvider.overrideWithValue(alunosApiFake),
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

      await tester.tap(find.text('Alunos').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Novo aluno'));
      await tester.pumpAndSettle();

      // Preenche os campos obrigatórios via TextField (Nome=0, CPF=1,
      // Telefone=3 — RG fica no meio, entre CPF e Telefone).
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Novo Aluno Teste');
      await tester.enterText(textFields.at(1), '11144477735');
      await tester.enterText(textFields.at(3), '11999999999');

      // Data de nascimento (showDatePicker) e Sexo (DropdownButton) só
      // atualizam `_dataNascimento`/`_sexo` de verdade (o que vai pro
      // payload) através da interação real — `onChanged` é um parâmetro de
      // construtor, não um campo acessível de fora — por isso a UI é
      // acionada de fato, em vez de tentar contornar.
      await tester.ensureVisible(find.text('Selecionar'));
      await tester.tap(find.text('Selecionar'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      // O calendário abre com `initialDate` (hoje) já selecionado — só
      // confirmar já satisfaz "campo preenchido", sem precisar escolher
      // um dia específico.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(DropdownButton<Sexo?>));
      await tester.tap(find.byType(DropdownButton<Sexo?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Masculino').last);
      await tester.pumpAndSettle();

      // Simula a seleção de uma foto sem depender do file picker nativo —
      // aciona o mesmo callback que `AppAvatarPicker._escolher()` chamaria
      // depois de o usuário escolher um arquivo de verdade.
      final avatarPicker = tester.widget<AppAvatarPicker>(find.byType(AppAvatarPicker));
      avatarPicker.onPicked!((bytes: _pngUmPixel, filename: 'foto.png'));
      await tester.pump();

      // --- Primeira tentativa: create() ok, uploadFoto() falha ---
      await tester.ensureVisible(find.text('Salvar'));
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(alunosApiFake.createCalls, 1);
      expect(alunosApiFake.updateCalls, 0);
      expect(alunosApiFake.uploadFotoCalls, 1);
      expect(
        find.textContaining('Os dados foram salvos, mas a foto não pôde ser enviada'),
        findsOneWidget,
      );
      // Continua na mesma tela — não navegou de volta pra lista.
      expect(find.text('Novo aluno'), findsWidgets);

      // --- Segunda tentativa: deve usar update(), nunca um 2º create() ---
      await tester.ensureVisible(find.text('Salvar'));
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(alunosApiFake.createCalls, 1, reason: 'nunca deve criar um segundo aluno');
      expect(alunosApiFake.updateCalls, 1);
      expect(alunosApiFake.uploadFotoCalls, 2);
    },
  );
}
