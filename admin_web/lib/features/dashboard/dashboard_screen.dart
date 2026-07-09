import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

final _dashboardProvider = FutureProvider.autoDispose<DashboardAcademia>((ref) {
  return ref.watch(dashboardApiProvider).get();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(_dashboardProvider);

    return dashboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (erro, _) => Center(child: Text(_mensagemErro(erro))),
      data: (dashboard) => _DashboardConteudo(dashboard: dashboard),
    );
  }
}

String _mensagemErro(Object erro) {
  if (erro is DioException && erro.response?.statusCode == 403) {
    return 'Seu perfil não tem acesso ao dashboard da academia.';
  }
  return 'Não foi possível carregar o dashboard.';
}

class _DashboardConteudo extends StatelessWidget {
  const _DashboardConteudo({required this.dashboard});

  final DashboardAcademia dashboard;

  @override
  Widget build(BuildContext context) {
    final cartoes = [
      (
        titulo: 'Total de alunos',
        valor: dashboard.totalAlunos,
        icon: Icons.groups_outlined,
      ),
      (
        titulo: 'Alunos ativos',
        valor: dashboard.alunosAtivos,
        icon: Icons.check_circle_outline,
      ),
      (
        titulo: 'Professores',
        valor: dashboard.totalProfessores,
        icon: Icons.badge_outlined,
      ),
      (
        titulo: 'Novos alunos (mês)',
        valor: dashboard.novosAlunosMes,
        icon: Icons.trending_up,
      ),
      (
        titulo: 'Usuários do sistema',
        valor: dashboard.usuariosDoSistema,
        icon: Icons.admin_panel_settings_outlined,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final cartao in cartoes)
                _CartaoMetrica(
                  titulo: cartao.titulo,
                  valor: cartao.valor,
                  icon: cartao.icon,
                ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Aniversariantes do mês',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (dashboard.aniversariantes.isEmpty)
            const Text('Nenhum aniversariante este mês.')
          else
            Card(
              child: Column(
                children: [
                  for (final aniversariante in dashboard.aniversariantes)
                    ListTile(
                      leading: const Icon(Icons.cake_outlined),
                      title: Text(aniversariante.nome),
                      trailing: Text(
                        DateFormat(
                          'dd/MM',
                        ).format(aniversariante.dataNascimento),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CartaoMetrica extends StatelessWidget {
  const _CartaoMetrica({
    required this.titulo,
    required this.valor,
    required this.icon,
  });

  final String titulo;
  final int valor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 220,
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$valor',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(titulo, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
