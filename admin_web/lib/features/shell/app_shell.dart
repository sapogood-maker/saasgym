import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const _destinos = [
    (path: '/', label: 'Dashboard', icon: Icons.dashboard_outlined),
    (path: '/alunos', label: 'Alunos', icon: Icons.groups_outlined),
    (path: '/professores', label: 'Professores', icon: Icons.badge_outlined),
    (path: '/perfil', label: 'Meu perfil', icon: Icons.person_outline),
  ];

  int _indiceSelecionado(String location) {
    final indice = _destinos.indexWhere(
      (destino) =>
          location == destino.path ||
          (destino.path != '/' && location.startsWith(destino.path)),
    );
    return indice == -1 ? 0 : indice;
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
    final indiceSelecionado = _indiceSelecionado(location);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: indiceSelecionado,
            onDestinationSelected: (indice) =>
                context.go(_destinos[indice].path),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: FlutterLogo(size: 32),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: IconButton(
                    tooltip: usuario != null
                        ? 'Sair (${usuario.nome})'
                        : 'Sair',
                    icon: const Icon(Icons.logout),
                    onPressed: () => _sair(context, ref),
                  ),
                ),
              ),
            ),
            destinations: [
              for (final destino in _destinos)
                NavigationRailDestination(
                  icon: Icon(destino.icon),
                  label: Text(destino.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Scaffold(
              appBar: AppBar(title: Text(_destinos[indiceSelecionado].label)),
              body: child,
            ),
          ),
        ],
      ),
    );
  }
}
