import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

/// Shell do admin_web — sidebar + header ao redor de qualquer página,
/// independente do que a página é. O Dashboard é só mais uma página dentro
/// dele, igual Alunos/Professores/Perfil; nenhuma delas sabe que o shell
/// existe (`child` recebe o conteúdo pronto do `ShellRoute`).
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  // Scaffold.of(context) exige um context abaixo do Scaffold na árvore —
  // o context de build() do AppShell fica acima dele. Chave estática
  // resolve sem precisar de um Builder só pra isso.
  static final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _destinos = [
    AppSidebarDestination(label: 'Dashboard', icon: AppIcons.dashboard, path: '/', section: 'Operação'),
    AppSidebarDestination(label: 'Alunos', icon: AppIcons.students, path: '/alunos', section: 'Operação'),
    AppSidebarDestination(label: 'Professores', icon: AppIcons.teachers, path: '/professores', section: 'Operação'),
    AppSidebarDestination(label: 'Planos', icon: AppIcons.plans, path: '/planos', section: 'Operação'),
    // Ainda sem tela — visíveis e inertes, preparando a navegação para
    // quando os módulos correspondentes chegarem (Módulo 2/Matrículas,
    // Módulo 4/Agenda, Módulo 3/Financeiro), em vez de aparecerem "do
    // nada" depois.
    AppSidebarDestination(label: 'Matrículas', icon: AppIcons.enrollment, path: '/matriculas', section: 'Operação', enabled: false),
    AppSidebarDestination(label: 'Agenda', icon: AppIcons.calendar, path: '/agenda', section: 'Operação', enabled: false),
    AppSidebarDestination(label: 'Financeiro', icon: AppIcons.finance, path: '/financeiro', section: 'Operação', enabled: false),
    AppSidebarDestination(label: 'Meu perfil', icon: AppIcons.profile, path: '/perfil', section: 'Conta'),
  ];

  String _cargoLabel(Role role) => switch (role) {
    Role.systemAdmin => 'Administrador do sistema',
    Role.academiaAdmin => 'Administrador',
    Role.recepcionista => 'Recepção',
    Role.professor => 'Professor',
    Role.aluno => 'Aluno',
  };

  String _tituloPagina(String location) {
    final destino = _destinos.firstWhere(
      (d) => location == d.path || (d.path != '/' && location.startsWith(d.path)),
      orElse: () => _destinos.first,
    );
    return destino.label;
  }

  Future<void> _sair(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authApiProvider).logout();
    } catch (_) {
      // Mesmo se a chamada de logout falhar (ex.: sessão já expirada), a
      // sessão local é encerrada de qualquer forma.
    }
    ref.read(authSessionProvider.notifier).clear();
    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authSessionProvider).user;
    final location = GoRouterState.of(context).matchedLocation;
    final breadcrumb = AppBreadcrumb([_tituloPagina(location)]);

    final sidebar = AppSidebar(
      academiaNome: usuario?.academiaNome ?? 'SaaSGym',
      planoNome: usuario?.planoNome,
      destinations: _destinos,
      currentPath: location,
      onDestinationSelected: (path) {
        // No mobile a sidebar vive num Drawer — sem fechar explicitamente,
        // ele fica aberto por cima da tela nova depois da navegação (o
        // Scaffold não fecha sozinho ao trocar de rota).
        if (context.isMobile) {
          _scaffoldKey.currentState?.closeDrawer();
        }
        context.go(path);
      },
      userNome: usuario?.nome ?? '',
      userCargo: usuario != null ? _cargoLabel(usuario.role) : '',
      onProfileTap: () => context.go('/perfil'),
      onLogout: () => _sair(context, ref),
    );

    if (context.isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        drawer: Drawer(width: 260, child: sidebar),
        appBar: AppHeader(breadcrumb: breadcrumb, onMenuTap: () => _scaffoldKey.currentState?.openDrawer()),
        body: child,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          sidebar,
          Expanded(
            child: Column(
              children: [
                AppHeader(breadcrumb: breadcrumb),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
