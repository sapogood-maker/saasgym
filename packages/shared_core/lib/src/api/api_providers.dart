import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import '../alunos/alunos_api.dart';
import '../auth/auth_api.dart';
import '../auth/auth_session.dart';
import '../dashboard/dashboard_api.dart';
import '../planos/planos_api.dart';
import '../professores/professores_api.dart';
import '../users/users_api.dart';

/// URL base da API — configurável via `--dart-define=API_BASE_URL=...`
/// (dev local, CI, Dockerfile). Sem o define, cai no backend local padrão.
const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000/api',
);

/// Único ApiClient do app — os callbacks de refresh escrevem de volta no
/// authSessionProvider, fechando o ciclo (token novo emitido pelo
/// interceptor vira o token usado nas próximas requisições).
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: _apiBaseUrl,
    getAccessToken: () => ref.read(authSessionProvider).accessToken,
    onTokenRefreshed: (token) {
      final atual = ref.read(authSessionProvider);
      if (atual.user != null) {
        ref
            .read(authSessionProvider.notifier)
            .setSession(accessToken: token, user: atual.user!);
      }
    },
    onRefreshFailed: () => ref.read(authSessionProvider.notifier).clear(),
  );
});

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider).dio),
);

final usersApiProvider = Provider<UsersApi>(
  (ref) => UsersApi(ref.watch(apiClientProvider).dio),
);

final dashboardApiProvider = Provider<DashboardApi>(
  (ref) => DashboardApi(ref.watch(apiClientProvider).dio),
);

final alunosApiProvider = Provider<AlunosApi>(
  (ref) => AlunosApi(ref.watch(apiClientProvider).dio),
);

final professoresApiProvider = Provider<ProfessoresApi>(
  (ref) => ProfessoresApi(ref.watch(apiClientProvider).dio),
);

final planosApiProvider = Provider<PlanosApi>(
  (ref) => PlanosApi(ref.watch(apiClientProvider).dio),
);
