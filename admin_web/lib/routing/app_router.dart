import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

import '../features/alunos/aluno_detail_screen.dart';
import '../features/alunos/aluno_form_screen.dart';
import '../features/alunos/alunos_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/design_system_gallery/design_system_gallery_screen.dart';
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
            path: '/perfil',
            builder: (context, state) => const PerfilScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/alunos/novo',
        builder: (context, state) => const AlunoFormScreen(),
      ),
      GoRoute(
        path: '/alunos/:id',
        builder: (context, state) =>
            AlunoDetailScreen(alunoId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/alunos/:id/editar',
        builder: (context, state) =>
            AlunoFormScreen(alunoId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/professores/novo',
        builder: (context, state) => const ProfessorFormScreen(),
      ),
      GoRoute(
        path: '/professores/:id',
        builder: (context, state) =>
            ProfessorDetailScreen(professorId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/professores/:id/editar',
        builder: (context, state) =>
            ProfessorFormScreen(professorId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/planos/novo',
        builder: (context, state) => const PlanoFormScreen(),
      ),
      GoRoute(
        path: '/planos/:id',
        builder: (context, state) =>
            PlanoDetailScreen(planoId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/planos/:id/editar',
        builder: (context, state) =>
            PlanoFormScreen(planoId: state.pathParameters['id']!),
      ),
    ],
  );
});
