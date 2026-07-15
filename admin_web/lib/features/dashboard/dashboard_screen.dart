import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

final _dashboardProvider = FutureProvider.autoDispose<DashboardAcademia>((ref) {
  return ref.watch(dashboardApiProvider).get();
});

final _formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

/// Centro de Operações da academia (docs/22) — a pergunta que a tela
/// responde é "o que eu preciso fazer agora?", não "aqui estão meus
/// indicadores". Por isso a ordem de prioridade é Alertas financeiros →
/// Agenda da semana → Navegação rápida → listas complementares →
/// Indicadores (por último) — e nenhuma seção usa gráfico.
///
/// Construída inteiramente com o Design System (`AppCard`, `MetricCard`,
/// `AppListTile`, `AppBadge`, `EmptyState`, `LoadingSkeleton`) — nenhum
/// widget específico desta tela.
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

String _iniciais(String texto) {
  final partes = texto.trim().split(RegExp(r'\s+'));
  if (partes.isEmpty || partes.first.isEmpty) return '?';
  final primeira = partes.first[0];
  final ultima = partes.length > 1 ? partes.last[0] : '';
  return (primeira + ultima).toUpperCase();
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
                'Aqui está o que precisa da sua atenção agora.',
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

class _DadosSkeleton extends StatelessWidget {
  const _DadosSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(title: 'Alertas financeiros', loading: true),
        SizedBox(height: AppSpacing.xl),
        AppCard(title: 'Agenda da semana', loading: true),
        SizedBox(height: AppSpacing.xl),
        AppCard(title: 'Alunos novos', loading: true),
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
        _AlertasFinanceirosSection(financeiro: dashboard.financeiro),
        const SizedBox(height: AppSpacing.xl),
        _AgendaSemanaSection(aulas: dashboard.aulasSemana),
        const SizedBox(height: AppSpacing.xl),
        const _NavegacaoRapidaSection(),
        const SizedBox(height: AppSpacing.xl),
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
}

/// Prioridade 1 — a única com valor em R$ e ação imediata (ligar pro
/// aluno). `inadimplenciaValor`/`inadimplenciaQuantidade` (sempre tempo
/// real) aparecem em destaque; a lista combina vencidas + a vencer nos
/// próximos dias, vencidas primeiro (docs/22, decisões 3/4).
class _AlertasFinanceirosSection extends StatelessWidget {
  final DashboardFinanceiroResumo financeiro;

  const _AlertasFinanceirosSection({required this.financeiro});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final temInadimplencia = financeiro.inadimplenciaQuantidade > 0;

    return AppCard(
      title: 'Alertas financeiros',
      subtitle: 'Mensalidades vencidas e a vencer nos próximos dias',
      actions: [
        AppBadge(
          temInadimplencia ? '${financeiro.inadimplenciaQuantidade} em atraso' : 'Em dia',
          tone: temInadimplencia ? AppBadgeTone.error : AppBadgeTone.success,
        ),
      ],
      child: financeiro.mensalidadesAlerta.isEmpty
          ? EmptyState(
              icon: AppIcons.finance,
              title: 'Nenhuma mensalidade vencida ou a vencer',
              actionLabel: 'Ver mensalidades',
              onAction: () => context.push('/financeiro/mensalidades'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (temInadimplencia) ...[
                  Text(
                    '${_formatoMoeda.format(financeiro.inadimplenciaValor)} em atraso no total',
                    style: AppTypography.bodySmall.copyWith(color: colors.error, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                for (final alerta in financeiro.mensalidadesAlerta)
                  AppListTile(
                    title: alerta.alunoNome,
                    subtitle: alerta.vencida
                        ? 'Venceu em ${DateFormat('dd/MM').format(alerta.dataVencimento)}'
                        : 'Vence em ${DateFormat('dd/MM').format(alerta.dataVencimento)}',
                    leadingText: _iniciais(alerta.alunoNome),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_formatoMoeda.format(alerta.valor), style: AppTypography.bodySmall.copyWith(color: colors.text)),
                        const SizedBox(height: AppSpacing.xs),
                        AppBadge(
                          alerta.vencida ? 'Vencida' : 'A vencer',
                          tone: alerta.vencida ? AppBadgeTone.error : AppBadgeTone.warning,
                        ),
                      ],
                    ),
                    onTap: () => context.push('/alunos/${alerta.alunoId}'),
                  ),
              ],
            ),
    );
  }
}

/// Prioridade 2 — aulas dos próximos dias agrupadas por dia, sem
/// paginação nem contador redundante (o tamanho da própria lista já
/// comunica quantas aulas há) — docs/22, decisão 5.
class _AgendaSemanaSection extends StatelessWidget {
  final List<Aula> aulas;

  const _AgendaSemanaSection({required this.aulas});

  @override
  Widget build(BuildContext context) {
    final grupos = _agruparPorDia(aulas);

    return AppCard(
      title: 'Agenda da semana',
      subtitle: 'Aulas dos próximos dias',
      child: grupos.isEmpty
          ? EmptyState(
              icon: AppIcons.calendar,
              title: 'Nenhuma aula agendada essa semana',
              actionLabel: 'Ver calendário',
              onAction: () => context.push('/agenda/calendario'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final grupo in grupos) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
                    child: Text(
                      _rotuloDia(grupo.key),
                      style: AppTypography.labelSmall.copyWith(color: context.colors.textFaint),
                    ),
                  ),
                  for (final aula in grupo.value)
                    AppListTile(
                      title: '${aula.horaInicio} · ${aula.turmaNome}',
                      subtitle: '${aula.modalidadeNome} · ${aula.professorNome}',
                      leadingText: _iniciais(aula.turmaNome),
                      trailing: AppBadge(
                        aula.status == AulaStatus.cancelada ? 'Cancelada' : 'Agendada',
                        tone: aula.status == AulaStatus.cancelada ? AppBadgeTone.neutral : AppBadgeTone.info,
                      ),
                      onTap: () => context.push('/agenda/calendario'),
                    ),
                ],
              ],
            ),
    );
  }
}

/// Agrupa por `Aula.data` (sempre meia-noite UTC do dia — mesmo valor pra
/// toda aula do mesmo dia) e ordena cada grupo por `horaInicio`.
List<MapEntry<DateTime, List<Aula>>> _agruparPorDia(List<Aula> aulas) {
  final grupos = <DateTime, List<Aula>>{};
  for (final aula in aulas) {
    grupos.putIfAbsent(aula.data, () => []).add(aula);
  }
  final entradas = grupos.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  for (final entrada in entradas) {
    entrada.value.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
  }
  return entradas;
}

const _diasSemana = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];

String _rotuloDia(DateTime dia) {
  final agora = DateTime.now().toUtc();
  final hoje = DateTime.utc(agora.year, agora.month, agora.day);
  final diferenca = dia.difference(hoje).inDays;
  if (diferenca == 0) return 'Hoje';
  if (diferenca == 1) return 'Amanhã';
  final nomeDia = _diasSemana[dia.weekday - 1];
  final capitalizado = '${nomeDia[0].toUpperCase()}${nomeDia.substring(1)}';
  return '$capitalizado, ${DateFormat('dd/MM').format(dia)}';
}

/// Prioridade 3 — atalhos pras telas mais acessadas a partir do
/// Dashboard, 100% frontend (rotas já existentes) — cobre o mesmo
/// propósito que os antigos placeholders "Ações pendentes"/"Últimas
/// atividades" cobriam, sem prometer conteúdo que não existe (docs/22,
/// decisões 1/7).
class _NavegacaoRapidaSection extends StatelessWidget {
  const _NavegacaoRapidaSection();

  static const _atalhos = [
    (label: 'Alunos', icon: AppIcons.students, path: '/alunos'),
    (label: 'Matrículas', icon: AppIcons.enrollment, path: '/matriculas'),
    (label: 'Mensalidades', icon: AppIcons.pendingActions, path: '/financeiro/mensalidades'),
    (label: 'Calendário', icon: AppIcons.calendar, path: '/agenda/calendario'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Navegação rápida', style: AppTypography.titleMedium.copyWith(color: context.colors.textMuted)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final atalho in _atalhos)
              _QuickActionTile(
                label: atalho.label,
                icon: atalho.icon,
                onTap: () => context.push(atalho.path),
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionTile({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 220,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.cardRaised,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Icon(icon, size: 16, color: colors.textMuted),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTypography.titleMedium.copyWith(color: colors.text),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(AppIcons.chevronRight, size: 16, color: colors.textFaint),
          ],
        ),
      ),
    );
  }
}
