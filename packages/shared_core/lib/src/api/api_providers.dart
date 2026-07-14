import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import '../agenda/feriados_api.dart';
import '../agenda/modalidades_api.dart';
import '../agenda/aula_alunos_api.dart';
import '../agenda/aulas_api.dart';
import '../agenda/recorrencias_api.dart';
import '../agenda/solicitacoes_reposicao_api.dart';
import '../agenda/turma_alunos_api.dart';
import '../agenda/turmas_api.dart';
import '../alunos/alunos_api.dart';
import '../auth/auth_api.dart';
import '../avaliacoes_fisicas/avaliacoes_fisicas_api.dart';
import '../auth/auth_session.dart';
import '../dashboard/dashboard_api.dart';
import '../financeiro/dashboard_financeiro_api.dart';
import '../financeiro/lancamentos_api.dart';
import '../financeiro/mensalidades_api.dart';
import '../matriculas/matriculas_api.dart';
import '../notifications/notificacoes_api.dart';
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

final matriculasApiProvider = Provider<MatriculasApi>(
  (ref) => MatriculasApi(ref.watch(apiClientProvider).dio),
);

final notificacoesApiProvider = Provider<NotificacoesApi>(
  (ref) => NotificacoesApi(ref.watch(apiClientProvider).dio),
);

final mensalidadesApiProvider = Provider<MensalidadesApi>(
  (ref) => MensalidadesApi(ref.watch(apiClientProvider).dio),
);

final lancamentosApiProvider = Provider<LancamentosApi>(
  (ref) => LancamentosApi(ref.watch(apiClientProvider).dio),
);

final dashboardFinanceiroApiProvider = Provider<DashboardFinanceiroApi>(
  (ref) => DashboardFinanceiroApi(ref.watch(apiClientProvider).dio),
);

final modalidadesApiProvider = Provider<ModalidadesApi>(
  (ref) => ModalidadesApi(ref.watch(apiClientProvider).dio),
);

final feriadosApiProvider = Provider<FeriadosApi>(
  (ref) => FeriadosApi(ref.watch(apiClientProvider).dio),
);

final turmasApiProvider = Provider<TurmasApi>(
  (ref) => TurmasApi(ref.watch(apiClientProvider).dio),
);

final recorrenciasApiProvider = Provider<RecorrenciasApi>(
  (ref) => RecorrenciasApi(ref.watch(apiClientProvider).dio),
);

final turmaAlunosApiProvider = Provider<TurmaAlunosApi>(
  (ref) => TurmaAlunosApi(ref.watch(apiClientProvider).dio),
);

final aulasApiProvider = Provider<AulasApi>(
  (ref) => AulasApi(ref.watch(apiClientProvider).dio),
);

final aulaAlunosApiProvider = Provider<AulaAlunosApi>(
  (ref) => AulaAlunosApi(ref.watch(apiClientProvider).dio),
);

final avaliacoesFisicasApiProvider = Provider<AvaliacoesFisicasApi>(
  (ref) => AvaliacoesFisicasApi(ref.watch(apiClientProvider).dio),
);

final solicitacoesReposicaoApiProvider = Provider<SolicitacoesReposicaoApi>(
  (ref) => SolicitacoesReposicaoApi(ref.watch(apiClientProvider).dio),
);
