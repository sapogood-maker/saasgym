import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

/// Sprint 6 (Agenda Avançada) MS4 — busca parametrizada só pelo usuário
/// autenticado (sem busca/paginação/filtro), mesmo padrão de
/// `_dashboardProvider`/`_perfilProvider`: `FutureProvider.autoDispose` em
/// vez do `ConsumerStatefulWidget`+`FutureBuilder` usado nas telas com
/// estado mutável (busca/página/filtro).
final _notificacoesProvider = FutureProvider.autoDispose<NotificacoesPaginadas>((ref) {
  return ref.watch(notificacoesApiProvider).list(pageSize: 10);
});

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
    AppSidebarDestination(label: 'Matrículas', icon: AppIcons.enrollment, path: '/matriculas', section: 'Operação'),
    AppSidebarDestination(label: 'Mensalidades', icon: AppIcons.pendingActions, path: '/financeiro/mensalidades', section: 'Operação'),
    AppSidebarDestination(label: 'Caixa', icon: AppIcons.finance, path: '/financeiro/caixa', section: 'Operação'),
    AppSidebarDestination(label: 'Painel', icon: AppIcons.activity, path: '/financeiro/painel', section: 'Operação'),
    AppSidebarDestination(label: 'Modalidades', icon: AppIcons.modalidade, path: '/agenda/modalidades', section: 'Operação'),
    AppSidebarDestination(label: 'Turmas', icon: AppIcons.turmas, path: '/agenda/turmas', section: 'Operação'),
    AppSidebarDestination(label: 'Calendário', icon: AppIcons.calendar, path: '/agenda/calendario', section: 'Operação'),
    AppSidebarDestination(label: 'Reposições', icon: AppIcons.reposicao, path: '/agenda/reposicoes', section: 'Operação'),
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

  void _abrirNotificacoes(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SizedBox(width: 380, child: _NotificacoesPopover()),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authSessionProvider).user;
    final location = GoRouterState.of(context).matchedLocation;
    final breadcrumb = AppBreadcrumb([_tituloPagina(location)]);
    final naoLidas = ref.watch(_notificacoesProvider).valueOrNull?.naoLidas ?? 0;

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
        appBar: AppHeader(
          breadcrumb: breadcrumb,
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
          notificacoesNaoLidas: naoLidas,
          onNotificationsTap: () => _abrirNotificacoes(context),
        ),
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
                AppHeader(
                  breadcrumb: breadcrumb,
                  notificacoesNaoLidas: naoLidas,
                  onNotificationsTap: () => _abrirNotificacoes(context),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Conteúdo real do sino de notificações (Sprint 6 MS4) — mesma posição
/// central de `_showComingSoonPopover`, agora com dado de verdade. Tocar
/// numa notificação não lida marca como lida (sem botão de "marcar todas"
/// nem "ver mais" ainda — 10 mais recentes cobrem o caso de uso real até
/// hoje, sem paginação nesta primeira versão do sino).
class _NotificacoesPopover extends ConsumerWidget {
  const _NotificacoesPopover();

  Future<void> _marcarComoLida(WidgetRef ref, String id) async {
    try {
      await ref.read(notificacoesApiProvider).marcarComoLida(id);
    } finally {
      ref.invalidate(_notificacoesProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final async = ref.watch(_notificacoesProvider);

    return AppCard(
      title: 'Notificações',
      child: async.when(
        loading: () => const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LoadingSkeleton(width: double.infinity, height: 16),
            SizedBox(height: AppSpacing.sm),
            LoadingSkeleton(width: double.infinity, height: 16),
          ],
        ),
        error: (erro, _) => EmptyState(
          icon: AppIcons.alert,
          title: 'Não foi possível carregar as notificações.',
          actionLabel: 'Tentar novamente',
          onAction: () => ref.invalidate(_notificacoesProvider),
        ),
        data: (paginado) {
          if (paginado.items.isEmpty) {
            return const EmptyState(icon: AppIcons.bell, title: 'Nenhuma notificação');
          }
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < paginado.items.length; i++) ...[
                    if (i > 0) Divider(color: colors.borderSoft, height: 1),
                    _NotificacaoRow(
                      notificacao: paginado.items[i],
                      onTap: paginado.items[i].lida
                          ? null
                          : () => _marcarComoLida(ref, paginado.items[i].id),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificacaoRow extends StatelessWidget {
  const _NotificacaoRow({required this.notificacao, required this.onTap});

  final Notificacao notificacao;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!notificacao.lida) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                  child: const SizedBox(width: 7, height: 7),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notificacao.titulo,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.text,
                      fontWeight: notificacao.lida ? FontWeight.w400 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(notificacao.mensagem, style: AppTypography.bodySmall.copyWith(color: colors.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    dataCurtaFormat.format(notificacao.createdAt),
                    style: AppTypography.bodySmall.copyWith(color: colors.textFaint, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
