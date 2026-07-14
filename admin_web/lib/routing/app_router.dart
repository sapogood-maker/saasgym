import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

import '../features/agenda/calendar_screen.dart';
import '../features/agenda/modalidades_screen.dart';
import '../features/agenda/turma_detail_screen.dart';
import '../features/agenda/turma_form_screen.dart';
import '../features/agenda/turmas_screen.dart';
import '../features/alunos/aluno_detail_screen.dart';
import '../features/alunos/aluno_form_screen.dart';
import '../features/alunos/alunos_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/design_system_gallery/design_system_gallery_screen.dart';
import '../features/financeiro/caixa_screen.dart';
import '../features/financeiro/mensalidades_screen.dart';
import '../features/financeiro/painel_financeiro_screen.dart';
import '../features/matriculas/matricula_detail_screen.dart';
import '../features/matriculas/matricula_form_screen.dart';
import '../features/matriculas/matriculas_screen.dart';
import '../features/perfil/perfil_screen.dart';
import '../features/planos/plano_detail_screen.dart';
import '../features/planos/plano_form_screen.dart';
import '../features/planos/planos_screen.dart';
import '../features/professores/professor_detail_screen.dart';
import '../features/professores/professor_form_screen.dart';
import '../features/professores/professores_screen.dart';
import '../features/shell/app_shell.dart';

/// Ponte entre o `authSessionProvider` (Riverpod) e o `refreshListenable`
/// do GoRouter — sem isso, o `redirect` só seria reavaliado numa navegação
/// explícita, e login/logout não empurrariam o usuário para a rota certa.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(authSessionProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated) {
        notifyListeners();
      }
    });
  }
}

/// Criado uma única vez (Provider comum, não autoDispose) — a reatividade a
/// mudanças de sessão vem do `refreshListenable`, não de recriar o router.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _AuthRefreshListenable(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final autenticado = ref.read(authSessionProvider).isAuthenticated;
      final indoParaLogin = state.matchedLocation == '/login';

      if (!autenticado && !indoParaLogin) {
        return '/login';
      }
      if (autenticado && indoParaLogin) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      // Catálogo interno do Design System — fora do ShellRoute de propósito
      // (tela cheia própria, sem sidebar/topbar). Link visível na navegação
      // só em kDebugMode a partir do MS4/MS5 (sidebar rica); por ora,
      // acessível direto pela URL.
      GoRoute(
        path: '/design-system',
        builder: (context, state) => const DesignSystemGalleryScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/alunos',
            builder: (context, state) => const AlunosScreen(),
          ),
          GoRoute(
            path: '/professores',
            builder: (context, state) => const ProfessoresScreen(),
          ),
          GoRoute(
            path: '/planos',
            builder: (context, state) => const PlanosScreen(),
          ),
          GoRoute(
            path: '/matriculas',
            builder: (context, state) => const MatriculasScreen(),
          ),
          GoRoute(
            path: '/financeiro/mensalidades',
            builder: (context, state) => MensalidadesScreen(
              initialMes: int.tryParse(state.uri.queryParameters['mes'] ?? ''),
              initialAno: int.tryParse(state.uri.queryParameters['ano'] ?? ''),
              initialBusca: state.uri.queryParameters['busca'],
            ),
          ),
          GoRoute(
            path: '/financeiro/caixa',
            builder: (context, state) => const CaixaScreen(),
          ),
          GoRoute(
            path: '/financeiro/painel',
            builder: (context, state) => const PainelFinanceiroScreen(),
          ),
          GoRoute(
            path: '/agenda/modalidades',
            builder: (context, state) => const ModalidadesScreen(),
          ),
          GoRoute(
            path: '/agenda/turmas',
            builder: (context, state) => const TurmasScreen(),
          ),
          GoRoute(
            path: '/agenda/calendario',
            builder: (context, state) => const CalendarScreen(),
          ),
          GoRoute(
            path: '/perfil',
            builder: (context, state) => const PerfilScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/alunos/novo',
        builder: (context, state) => const AlunoFormScreen(key: ValueKey('aluno-novo')),
      ),
      GoRoute(
        path: '/alunos/:id',
        builder: (context, state) => AlunoDetailScreen(
          key: ValueKey('aluno-detalhe-${state.pathParameters['id']}'),
          alunoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/alunos/:id/editar',
        builder: (context, state) => AlunoFormScreen(
          key: ValueKey('aluno-${state.pathParameters['id']}'),
          alunoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/professores/novo',
        builder: (context, state) => const ProfessorFormScreen(key: ValueKey('professor-novo')),
      ),
      GoRoute(
        path: '/professores/:id',
        builder: (context, state) => ProfessorDetailScreen(
          key: ValueKey('professor-detalhe-${state.pathParameters['id']}'),
          professorId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/professores/:id/editar',
        builder: (context, state) => ProfessorFormScreen(
          key: ValueKey('professor-${state.pathParameters['id']}'),
          professorId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/planos/novo',
        builder: (context, state) => const PlanoFormScreen(key: ValueKey('plano-novo')),
      ),
      GoRoute(
        path: '/planos/:id',
        builder: (context, state) => PlanoDetailScreen(
          key: ValueKey('plano-detalhe-${state.pathParameters['id']}'),
          planoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/planos/:id/editar',
        builder: (context, state) => PlanoFormScreen(
          key: ValueKey('plano-${state.pathParameters['id']}'),
          planoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/matriculas/novo',
        builder: (context, state) => const MatriculaFormScreen(key: ValueKey('matricula-novo')),
      ),
      GoRoute(
        path: '/matriculas/:id',
        builder: (context, state) => MatriculaDetailScreen(
          key: ValueKey('matricula-detalhe-${state.pathParameters['id']}'),
          matriculaId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/matriculas/:id/editar',
        builder: (context, state) => MatriculaFormScreen(
          key: ValueKey('matricula-${state.pathParameters['id']}'),
          matriculaId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/agenda/turmas/novo',
        builder: (context, state) => const TurmaFormScreen(key: ValueKey('turma-novo')),
      ),
      GoRoute(
        path: '/agenda/turmas/:id',
        builder: (context, state) => TurmaDetailScreen(
          key: ValueKey('turma-detalhe-${state.pathParameters['id']}'),
          turmaId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/agenda/turmas/:id/editar',
        builder: (context, state) => TurmaFormScreen(
          key: ValueKey('turma-${state.pathParameters['id']}'),
          turmaId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});
