import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

final _dashboardProvider = FutureProvider.autoDispose<DashboardAcademia>((ref) {
  return ref.watch(dashboardApiProvider).get();
});

/// Dashboard operacional — a pergunta que a tela responde é "o que eu
/// preciso fazer hoje?", não "aqui estão meus indicadores". Por isso os
/// indicadores (seção "Indicadores") vêm por último, depois de alertas,
/// ações pendentes, agenda e listas acionáveis — ordem que reflete
/// prioridade operacional, não importância técnica dos dados.
///
/// Construída inteiramente com o Design System (`AppCard`, `MetricCard`,
/// `AppListTile`, `EmptyState`, `LoadingSkeleton`) — nenhum widget
/// específico desta tela.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(_dashboardProvider);
    final usuario = ref.watch(authSessionProvider).user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(nome: usuario?.nome),
            const SizedBox(height: AppSpacing.xxl),

            // Prioridades 1-3: não dependem do fetch do dashboard (são
            // placeholders estáticos) — aparecem imediatamente, sem
            // esperar a rede.
            _PrioritySection(
              title: 'Alertas importantes',
              child: EmptyState.comingSoon(
                icon: AppIcons.alert,
                title: 'Alunos inadimplentes e mensalidades vencendo',
                description: 'Vai aparecer aqui assim que o módulo financeiro existir.',
                sprintTag: 'MÓDULO 3 · FINANCEIRO',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _PrioritySection(
              title: 'Ações pendentes',
              child: EmptyState.comingSoon(
                icon: AppIcons.pendingActions,
                title: 'Matrículas pendentes de confirmação',
                description: 'Vai aparecer aqui assim que o fluxo de matrículas existir.',
                sprintTag: 'MÓDULO 2 · MATRÍCULAS',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _PrioritySection(
              title: 'Agenda do dia',
              child: EmptyState.comingSoon(
                icon: AppIcons.calendar,
                title: 'Aulas e horários de personal de hoje',
                description: 'Vai aparecer aqui assim que a agenda existir.',
                sprintTag: 'MÓDULO 4 · MS7',
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Prioridades 4-7: dependem do fetch do dashboard.
            dashboardAsync.when(
              loading: () => const _DadosSkeleton(),
              error: (erro, _) => _DadosErro(
                mensagem: _mensagemErro(erro),
                onTentarNovamente: () => ref.invalidate(_dashboardProvider),
              ),
              data: (dashboard) => _DadosConteudo(dashboard: dashboard),
            ),
          ],
        ),
      ),
    );
  }
}

String _mensagemErro(Object erro) {
  if (erro is DioException && erro.response?.statusCode == 403) {
    return 'Seu perfil não tem acesso ao dashboard da academia.';
  }
  return 'Não foi possível carregar o dashboard.';
}

class _Header extends StatelessWidget {
  final String? nome;

  const _Header({this.nome});

  String get _saudacao {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Bom dia';
    if (hora < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final partesNome = nome?.trim().split(RegExp(r'\s+'));
    final primeiroNome = (partesNome != null && partesNome.isNotEmpty) ? partesNome.first : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                primeiroNome != null ? '$_saudacao, $primeiroNome' : _saudacao,
                style: AppTypography.displayLarge.copyWith(color: colors.text),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Aqui está o que precisa da sua atenção hoje.',
                style: AppTypography.bodyMedium.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Text(
              dataCurtaFormat.format(DateTime.now()),
              style: AppTypography.monoSmall.copyWith(color: colors.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrioritySection extends StatelessWidget {
  final String title;
  final Widget child;

  const _PrioritySection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.titleMedium.copyWith(color: colors.textMuted)),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: child),
      ],
    );
  }
}

class _DadosSkeleton extends StatelessWidget {
  const _DadosSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(title: 'Alunos novos', loading: true),
        SizedBox(height: AppSpacing.xl),
        AppCard(title: 'Aniversariantes', loading: true),
      ],
    );
  }
}

class _DadosErro extends StatelessWidget {
  final String mensagem;
  final VoidCallback onTentarNovamente;

  const _DadosErro({required this.mensagem, required this.onTentarNovamente});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: EmptyState(
        icon: AppIcons.alert,
        title: mensagem,
        actionLabel: 'Tentar novamente',
        onAction: onTentarNovamente,
      ),
    );
  }
}

class _DadosConteudo extends StatelessWidget {
  final DashboardAcademia dashboard;

  const _DadosConteudo({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          title: 'Alunos novos',
          subtitle: 'Cadastrados este mês',
          actions: [AppBadge('${dashboard.novosAlunosMes}')],
          child: dashboard.alunosNovos.isEmpty
              ? EmptyState(
                  icon: AppIcons.newStudent,
                  title: 'Nenhum aluno novo este mês',
                  actionLabel: 'Cadastrar aluno',
                  onAction: () => context.push('/alunos/novo'),
                )
              : Column(
                  children: [
                    for (final aluno in dashboard.alunosNovos)
                      AppListTile(
                        title: aluno.nome,
                        subtitle: 'Cadastrado em ${DateFormat('dd/MM').format(aluno.createdAt)}',
                        leadingText: _iniciais(aluno.nome),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          title: 'Aniversariantes',
          subtitle: 'Neste mês',
          actions: [AppBadge('${dashboard.aniversariantes.length}')],
          child: dashboard.aniversariantes.isEmpty
              ? EmptyState(
                  icon: AppIcons.birthday,
                  title: 'Nenhum aniversariante este mês',
                  actionLabel: 'Ver todos os alunos',
                  onAction: () => context.push('/alunos'),
                )
              : Column(
                  children: [
                    for (final aniversariante in dashboard.aniversariantes)
                      AppListTile(
                        title: aniversariante.nome,
                        leadingText: _iniciais(aniversariante.nome),
                        trailing: AppBadge(DateFormat('dd/MM').format(aniversariante.dataNascimento)),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _PrioritySection(
          title: 'Últimas atividades',
          child: const EmptyState.comingSoon(
            icon: AppIcons.history,
            title: 'Histórico de ações da equipe',
            description: 'Login, cadastros e edições recentes vão aparecer aqui.',
            sprintTag: 'EM DESENVOLVIMENTO',
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('Indicadores', style: AppTypography.titleMedium.copyWith(color: context.colors.textMuted)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            MetricCard(label: 'Alunos ativos', value: '${dashboard.alunosAtivos}', icon: AppIcons.students),
            MetricCard(label: 'Total de alunos', value: '${dashboard.totalAlunos}', icon: AppIcons.students),
            MetricCard(label: 'Professores', value: '${dashboard.totalProfessores}', icon: AppIcons.teachers),
            MetricCard(label: 'Usuários do sistema', value: '${dashboard.usuariosDoSistema}', icon: AppIcons.profile),
          ],
        ),
      ],
    );
  }

  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (primeira + ultima).toUpperCase();
  }
}
