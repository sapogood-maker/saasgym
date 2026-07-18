import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

import 'dashboard_extras.dart';

final _dashboardProvider = FutureProvider.autoDispose<DashboardAcademia>((ref) {
  return ref.watch(dashboardApiProvider).get();
});

/// Centro de Operações da academia — painel nível comercial (Sprint de
/// Redesenho do Dashboard, docs/32). A pergunta que a tela responde
/// continua sendo "o que eu preciso fazer agora?" (não "aqui estão meus
/// indicadores"), mas agora organizada em blocos com hierarquia visual
/// clara: métricas principais → agenda → aniversariantes → financeiro →
/// indicadores → pendências → dica do dia.
///
/// Todo indicador exibido vem de dado real de algum endpoint já existente
/// — nenhum é aproximado nem inventado. Onde o dado pedido não existe hoje
/// no backend (check-in avulso, frequência agregada da academia, avaliação
/// física "pendente"), a métrica foi substituída por outra igualmente real
/// (ver `dashboard_extras.dart`), nunca por um número estimado.
///
/// Dois providers, dois tempos de carregamento independentes:
/// [_dashboardProvider] (rápido, uma chamada) drena as Linhas 1-3;
/// [dashboardExtrasProvider] (várias chamadas em paralelo, reaproveitando
/// endpoints de listagem já existentes) drena as Linhas 4-6 — cada bloco
/// mostra seu próprio esqueleto/erro, sem travar o resto da tela.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(_dashboardProvider);
    final extrasAsync = ref.watch(dashboardExtrasProvider);
    final usuario = ref.watch(authSessionProvider).user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
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
              data: (dashboard) => _DadosConteudo(dashboard: dashboard, extrasAsync: extrasAsync, ref: ref),
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

DateTime _hojeUtc() {
  final agora = DateTime.now().toUtc();
  return DateTime.utc(agora.year, agora.month, agora.day);
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
        if (nome != null && nome!.trim().isNotEmpty) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primaryWash, colors.card],
                stops: const [0, 0.7],
              ),
              border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                _iniciais(nome!),
                style: AppTypography.titleLarge.copyWith(color: colors.primary),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
        ],
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
        AppCard(title: 'Agenda de hoje', loading: true),
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

/// Cabeçalho leve reutilizado entre as seções "Financeiro", "Indicadores
/// rápidos" e "Pendências" — um ícone temático (chip com fundo sutil) +
/// texto, em vez de só texto cinza solto, pra dar uma âncora visual a cada
/// bloco secundário sem competir com os cards em si.
class _SectionLabel extends StatelessWidget {
  final String texto;
  final IconData icon;

  const _SectionLabel(this.texto, {required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.cardRaised,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(icon, size: 14, color: colors.textMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(texto, style: AppTypography.titleMedium.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }
}

class _DadosConteudo extends StatelessWidget {
  final DashboardAcademia dashboard;
  final AsyncValue<DashboardExtras> extrasAsync;
  final WidgetRef ref;

  const _DadosConteudo({required this.dashboard, required this.extrasAsync, required this.ref});

  @override
  Widget build(BuildContext context) {
    final hoje = _hojeUtc();
    final aulasHoje = dashboard.aulasSemana.where((a) => a.data == hoje).toList()
      ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
    final alunosPrevistosHoje = aulasHoje.fold<int>(0, (soma, a) => soma + a.totalAlunos);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------- Linha 1 — cards principais ----------
        _MetricasPrincipaisRow(
          dashboard: dashboard,
          extrasAsync: extrasAsync,
          aulasHojeCount: aulasHoje.length,
          alunosPrevistosHoje: alunosPrevistosHoje,
        ),
        const SizedBox(height: AppSpacing.xl),

        // ---------- Linha 2 — agenda de hoje + resumo da semana ----------
        LayoutBuilder(
          builder: (context, constraints) {
            final empilhar = context.isTouch;
            final agenda = _AgendaHojeSection(aulasHoje: aulasHoje);
            final resumoSemana = _ResumoSemanaSection(aulasSemana: dashboard.aulasSemana, hoje: hoje);
            if (empilhar) {
              return Column(
                children: [agenda, const SizedBox(height: AppSpacing.xl), resumoSemana],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 2, child: agenda),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(child: resumoSemana),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),

        // ---------- Linha 3 — aniversariantes ----------
        _AniversariantesSection(aniversariantes: dashboard.aniversariantes, hoje: hoje),
        const SizedBox(height: AppSpacing.xxl),

        // ---------- Linha 4 — financeiro ----------
        _SectionLabel('Financeiro', icon: AppIcons.finance),
        extrasAsync.when(
          loading: () => const AppCard(loading: true),
          error: (_, _) => const AppCard(
            child: Text('Não foi possível carregar os indicadores financeiros.'),
          ),
          data: (extras) => _FinanceiroSection(
            vencidas: dashboard.financeiro.inadimplenciaQuantidade,
            venceHoje: extras.mensalidadesVenceHoje,
            venceEstaSemana: extras.mensalidadesVenceEstaSemana,
            venceEsteMes: extras.mensalidadesVenceEsteMes,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ---------- Linha 5 — indicadores rápidos ----------
        _SectionLabel('Indicadores rápidos', icon: AppIcons.activity),
        extrasAsync.when(
          loading: () => const AppCard(loading: true),
          error: (_, _) => const AppCard(
            child: Text('Não foi possível carregar os indicadores rápidos.'),
          ),
          data: (extras) => _IndicadoresRapidosRow(dashboard: dashboard, extras: extras),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ---------- Linha 6 — pendências ----------
        _SectionLabel('Pendências', icon: AppIcons.pendingActions),
        extrasAsync.when(
          loading: () => const AppCard(loading: true),
          error: (_, _) => const AppCard(child: Text('Não foi possível carregar as pendências.')),
          data: (extras) => _PendenciasSection(
            mensalidadesVencidas: dashboard.financeiro.inadimplenciaQuantidade,
            extras: extras,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ---------- Rodapé — dica do dia ----------
        const _DicaDoDia(),
      ],
    );
  }
}

/// Linha 1 — 5 métricas principais, todas com dado real. "Alunos ativos"
/// usa `novosAlunosMes` como contexto (não é uma comparação líquida com o
/// mês anterior — essa curva não existe, ver docs/32 — mas é um número
/// real, só rotulado com precisão). "Mensalidades vencidas" não recebe seta
/// de tendência: não existe histórico pra comparar, e mostrar uma seta
/// aleatória seria inventar direção onde não há dado — mas ganha
/// `tone: error` quando há alguma vencida, pra não ficar visualmente
/// empatada com uma métrica neutra qualquer (docs/30, mesmo achado do
/// Painel Financeiro).
class _MetricasPrincipaisRow extends StatelessWidget {
  final DashboardAcademia dashboard;
  final AsyncValue<DashboardExtras> extrasAsync;
  final int aulasHojeCount;
  final int alunosPrevistosHoje;

  const _MetricasPrincipaisRow({
    required this.dashboard,
    required this.extrasAsync,
    required this.aulasHojeCount,
    required this.alunosPrevistosHoje,
  });

  @override
  Widget build(BuildContext context) {
    final matriculasAtivas = extrasAsync.valueOrNull?.matriculasAtivas;

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        MetricCard(
          label: 'Alunos ativos',
          value: '${dashboard.alunosAtivos}',
          icon: AppIcons.students,
          highlight: true,
          deltaLabel: dashboard.novosAlunosMes > 0 ? '+${dashboard.novosAlunosMes} este mês' : null,
          trend: dashboard.novosAlunosMes > 0 ? AppMetricTrend.up : AppMetricTrend.neutral,
        ),
        MetricCard(
          label: 'Matrículas ativas',
          value: matriculasAtivas != null ? '$matriculasAtivas' : '—',
          icon: AppIcons.enrollment,
          loading: extrasAsync.isLoading,
        ),
        MetricCard(
          label: 'Mensalidades vencidas',
          value: '${dashboard.financeiro.inadimplenciaQuantidade}',
          icon: AppIcons.finance,
          tone: dashboard.financeiro.inadimplenciaQuantidade > 0 ? AppBadgeTone.error : null,
        ),
        MetricCard(label: 'Aulas hoje', value: '$aulasHojeCount', icon: AppIcons.calendar),
        MetricCard(label: 'Alunos previstos hoje', value: '$alunosPrevistosHoje', icon: AppIcons.activity),
      ],
    );
  }
}

/// Linha 2 (esquerda) — aulas de hoje: horário, professor, modalidade,
/// sala e status, exatamente os campos pedidos, todos já presentes em
/// `Aula`.
class _AgendaHojeSection extends StatelessWidget {
  final List<Aula> aulasHoje;

  const _AgendaHojeSection({required this.aulasHoje});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Agenda de hoje',
      subtitle: dataCurtaFormat.format(DateTime.now()),
      actions: [AppBadge('${aulasHoje.length}')],
      child: aulasHoje.isEmpty
          ? EmptyState(
              icon: AppIcons.calendar,
              title: 'Nenhuma aula hoje',
              actionLabel: 'Ver calendário',
              onAction: () => context.push('/agenda/calendario'),
            )
          : Column(
              children: [
                for (final aula in aulasHoje)
                  AppListTile(
                    title: '${aula.horaInicio} · ${aula.modalidadeNome}',
                    subtitle: [
                      aula.professorNome,
                      if (aula.local != null && aula.local!.isNotEmpty) aula.local!,
                    ].join(' · '),
                    leadingText: _iniciais(aula.turmaNome),
                    trailing: AppBadge(
                      aula.status == AulaStatus.cancelada ? 'Cancelada' : 'Agendada',
                      tone: aula.status == AulaStatus.cancelada ? AppBadgeTone.neutral : AppBadgeTone.info,
                    ),
                    onTap: () => context.push('/agenda/calendario'),
                  ),
              ],
            ),
    );
  }
}

/// Linha 2 (direita) — densidade de aulas dos próximos 7 dias, calculada
/// localmente a partir da mesma lista já carregada (`aulasSemana`), sem
/// nenhuma chamada extra.
class _ResumoSemanaSection extends StatelessWidget {
  final List<Aula> aulasSemana;
  final DateTime hoje;

  const _ResumoSemanaSection({required this.aulasSemana, required this.hoje});

  static const _diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dias = List.generate(7, (i) => hoje.add(Duration(days: i)));
    final contagem = <DateTime, int>{
      for (final dia in dias)
        dia: aulasSemana
            .where((a) => a.data == dia && a.status != AulaStatus.cancelada)
            .length,
    };
    final maiorContagem = contagem.values.fold<int>(0, (max, v) => v > max ? v : max);

    return AppCard(
      title: 'Semana',
      subtitle: 'Aulas por dia',
      onTap: () => context.push('/agenda/calendario'),
      child: Column(
        children: [
          for (final dia in dias)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 68,
                    child: Text(
                      '${_diasSemana[dia.weekday - 1]} ${DateFormat('dd/MM').format(dia)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: dia == hoje ? colors.primary : colors.textMuted,
                        fontWeight: dia == hoje ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          color: colors.cardRaised,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: maiorContagem == 0 ? 0 : (contagem[dia] ?? 0) / maiorContagem,
                              heightFactor: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: dia == hoje
                                        ? [colors.primary.withValues(alpha: 0.6), colors.primary]
                                        : [colors.info.withValues(alpha: 0.6), colors.info],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 18,
                    child: Text(
                      '${contagem[dia] ?? 0}',
                      textAlign: TextAlign.end,
                      style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
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

/// Linha 3 — aniversariantes agrupados por proximidade. `aniversariantes`
/// já vem só do mês corrente (backend); o agrupamento é puramente visual,
/// baseado na diferença entre o dia do aniversário e o dia de hoje —
/// aniversários já passados neste mês caem em "Demais do mês" junto com os
/// que ainda faltam mais de 14 dias (não existe um 5º grupo "já passou" no
/// pedido original, e inventar um sem necessidade real não ajuda).
class _AniversariantesSection extends StatelessWidget {
  final List<Aniversariante> aniversariantes;
  final DateTime hoje;

  const _AniversariantesSection({required this.aniversariantes, required this.hoje});

  @override
  Widget build(BuildContext context) {
    final hojeList = <Aniversariante>[];
    final estaSemana = <Aniversariante>[];
    final proximaSemana = <Aniversariante>[];
    final demais = <Aniversariante>[];

    for (final a in aniversariantes) {
      final diff = a.dataNascimento.day - hoje.day;
      if (diff == 0) {
        hojeList.add(a);
      } else if (diff >= 1 && diff <= 7) {
        estaSemana.add(a);
      } else if (diff >= 8 && diff <= 14) {
        proximaSemana.add(a);
      } else {
        demais.add(a);
      }
    }

    final grupos = [
      ('Hoje', hojeList, AppBadgeTone.primary),
      ('Esta semana', estaSemana, AppBadgeTone.info),
      ('Próxima semana', proximaSemana, AppBadgeTone.neutral),
      ('Demais do mês', demais, AppBadgeTone.neutral),
    ];

    return AppCard(
      title: 'Aniversariantes',
      subtitle: 'Neste mês',
      actions: [
        AppBadge('${aniversariantes.length}'),
        const SizedBox(width: AppSpacing.sm),
        TextButton(onPressed: () => context.push('/alunos'), child: const Text('Ver todos')),
      ],
      child: aniversariantes.isEmpty
          ? EmptyState(icon: AppIcons.birthday, title: 'Nenhum aniversariante este mês')
          : Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.lg,
              children: [
                for (final (rotulo, lista, tone) in grupos)
                  if (lista.isNotEmpty) _AniversarianteGrupo(rotulo: rotulo, pessoas: lista, tone: tone),
              ],
            ),
    );
  }
}

class _AniversarianteGrupo extends StatelessWidget {
  final String rotulo;
  final List<Aniversariante> pessoas;
  final AppBadgeTone tone;

  const _AniversarianteGrupo({required this.rotulo, required this.pessoas, required this.tone});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(rotulo, style: AppTypography.labelSmall.copyWith(color: colors.textFaint)),
              const SizedBox(width: AppSpacing.xs),
              AppBadge('${pessoas.length}', tone: tone),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final pessoa in pessoas)
            AppListTile(
              title: pessoa.nome,
              leadingText: _iniciais(pessoa.nome),
              trailing: AppBadge(DateFormat('dd/MM').format(pessoa.dataNascimento)),
            ),
        ],
      ),
    );
  }
}

/// Linha 4 — só contagens reais, sem percentual calculado e sem valor em
/// R$ (regra explícita: "nunca mostrar valores financeiros, mostrar apenas
/// indicadores"). "Vencidas" vem do mesmo campo em tempo real que os
/// Alertas financeiros já usavam; as outras três vêm de
/// `DashboardExtras`, documentadas em `dashboard_extras.dart`.
class _FinanceiroSection extends StatelessWidget {
  final int vencidas;
  final int venceHoje;
  final int venceEstaSemana;
  final int venceEsteMes;

  const _FinanceiroSection({
    required this.vencidas,
    required this.venceHoje,
    required this.venceEstaSemana,
    required this.venceEsteMes,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      subtitle: 'Mensalidades pendentes — contagens reais, sem estimativa',
      actions: [TextButton(onPressed: () => context.push('/financeiro/mensalidades'), child: const Text('Ver todas'))],
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          MetricCard(
            label: 'Vencidas',
            value: '$vencidas',
            icon: AppIcons.alert,
            width: 200,
            tone: vencidas > 0 ? AppBadgeTone.error : null,
          ),
          MetricCard(label: 'Vencem hoje', value: '$venceHoje', icon: AppIcons.clock, width: 200),
          MetricCard(label: 'Vencem esta semana', value: '$venceEstaSemana', icon: AppIcons.calendar, width: 200),
          MetricCard(label: 'Vencem este mês', value: '$venceEsteMes', icon: AppIcons.finance, width: 200),
        ],
      ),
    );
  }
}

/// Linha 5 — 4 indicadores reais. "Novos alunos" não tem seta de
/// tendência (sem mês anterior pra comparar); os outros três comparam com
/// o mês anterior de verdade (dado histórico real, não estimado).
class _IndicadoresRapidosRow extends StatelessWidget {
  final DashboardAcademia dashboard;
  final DashboardExtras extras;

  const _IndicadoresRapidosRow({required this.dashboard, required this.extras});

  static (String?, AppMetricTrend) _delta(int atual, int? anterior) {
    if (anterior == null) return (null, AppMetricTrend.neutral);
    final diferenca = atual - anterior;
    if (diferenca == 0) return ('Igual ao mês anterior', AppMetricTrend.neutral);
    final sinal = diferenca > 0 ? '+' : '';
    return ('$sinal$diferenca vs. mês anterior', diferenca > 0 ? AppMetricTrend.up : AppMetricTrend.down);
  }

  @override
  Widget build(BuildContext context) {
    final (deltaMatriculas, trendMatriculas) = _delta(extras.novasMatriculasMes, extras.novasMatriculasMesAnterior);
    final (deltaCancelamentos, trendCancelamentos) = _delta(extras.cancelamentosMes, extras.cancelamentosMesAnterior);
    final (deltaAulas, trendAulas) = _delta(extras.aulasRealizadasMes, extras.aulasRealizadasMesAnterior);

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        MetricCard(label: 'Novos alunos (mês)', value: '${dashboard.novosAlunosMes}', icon: AppIcons.newStudent),
        MetricCard(
          label: 'Novas matrículas (mês)',
          value: '${extras.novasMatriculasMes}',
          icon: AppIcons.enrollment,
          deltaLabel: deltaMatriculas,
          trend: trendMatriculas,
        ),
        MetricCard(
          label: 'Cancelamentos (mês)',
          value: '${extras.cancelamentosMes}',
          icon: AppIcons.block,
          // Cancelamento caindo é bom — inverte a leitura de cor em relação
          // às outras métricas (queda = verde, alta = vermelho).
          deltaLabel: deltaCancelamentos,
          trend: switch (trendCancelamentos) {
            AppMetricTrend.up => AppMetricTrend.down,
            AppMetricTrend.down => AppMetricTrend.up,
            AppMetricTrend.neutral => AppMetricTrend.neutral,
          },
        ),
        MetricCard(
          label: 'Aulas realizadas (mês)',
          value: '${extras.aulasRealizadasMes}',
          icon: AppIcons.attendance,
          deltaLabel: deltaAulas,
          trend: trendAulas,
        ),
      ],
    );
  }
}

/// Linha 6 — ações pendentes reais, cada uma com contagem exata e atalho
/// pra tela onde a recepção resolve. "Avaliações físicas pendentes" não
/// existe (avaliação física não tem estado de pendência) — removida, não
/// substituída por um conceito inventado.
class _PendenciasSection extends StatelessWidget {
  final int mensalidadesVencidas;
  final DashboardExtras extras;

  const _PendenciasSection({required this.mensalidadesVencidas, required this.extras});

  @override
  Widget build(BuildContext context) {
    final itens = [
      if (mensalidadesVencidas > 0)
        _PendingActionData(
          icon: AppIcons.finance,
          titulo: 'Mensalidades vencidas',
          descricao: 'Cobranças em atraso aguardando pagamento',
          contador: mensalidadesVencidas,
          tone: AppBadgeTone.error,
          onTap: () => context.push('/financeiro/mensalidades'),
        ),
      if (extras.reposicoesPendentes > 0)
        _PendingActionData(
          icon: AppIcons.reposicao,
          titulo: 'Reposições aguardando aprovação',
          descricao: 'Solicitações de alunos ainda sem resposta',
          contador: extras.reposicoesPendentes,
          tone: AppBadgeTone.warning,
          onTap: () => context.push('/agenda/reposicoes'),
        ),
      if (extras.matriculasVencendoEmBreve > 0)
        _PendingActionData(
          icon: AppIcons.enrollment,
          titulo: 'Matrículas próximas do vencimento',
          descricao: 'Vigência termina nos próximos $diasJanelaVencimentoMatricula dias',
          contador: extras.matriculasVencendoEmBreve,
          tone: AppBadgeTone.warning,
          onTap: () => context.push('/matriculas'),
        ),
      if (extras.notificacoesNaoLidas > 0)
        _PendingActionData(
          icon: AppIcons.bell,
          titulo: 'Notificações importantes',
          descricao: 'Avisos ainda não lidos — confira o sino no topo',
          contador: extras.notificacoesNaoLidas,
          tone: AppBadgeTone.info,
          onTap: null,
        ),
    ];

    return AppCard(
      child: itens.isEmpty
          ? EmptyState(icon: AppIcons.circleCheck, title: 'Nenhuma pendência no momento')
          : Column(
              children: [for (final item in itens) _PendingActionTile(data: item)],
            ),
    );
  }
}

class _PendingActionData {
  const _PendingActionData({
    required this.icon,
    required this.titulo,
    required this.descricao,
    required this.contador,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String titulo;
  final String descricao;
  final int contador;
  final AppBadgeTone tone;
  final VoidCallback? onTap;
}

/// Linha de pendência — ícone + descrição + contador + ação, exatamente a
/// composição pedida. Não reaproveita `AppListTile` porque este precisa de
/// um chip de ícone (estado da pendência), não do avatar de iniciais
/// (pessoa) que `AppListTile` sempre desenha.
class _PendingActionTile extends StatelessWidget {
  final _PendingActionData data;

  const _PendingActionTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (Color background, Color foreground) = switch (data.tone) {
      AppBadgeTone.error => (colors.errorWash, colors.error),
      AppBadgeTone.warning => (colors.warningWash, colors.warning),
      AppBadgeTone.info => (colors.infoWash, colors.info),
      AppBadgeTone.success => (colors.successWash, colors.success),
      AppBadgeTone.primary || AppBadgeTone.neutral => (colors.cardRaised, colors.textMuted),
    };

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Icon(data.icon, size: 18, color: foreground),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(data.titulo, style: AppTypography.titleMedium.copyWith(color: colors.text)),
                Text(data.descricao, style: AppTypography.bodySmall.copyWith(color: colors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppBadge('${data.contador}', tone: data.tone),
          if (data.onTap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(AppIcons.chevronRight, size: 16, color: colors.textFaint),
          ],
        ],
      ),
    );

    if (data.onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        hoverColor: colors.cardRaised,
        child: content,
      ),
    );
  }
}

/// Rodapé — dica do dia. Conteúdo estático (sem dependência de dado),
/// escolhida de forma determinística pelo dia do ano, pra não trocar a
/// cada rebuild da tela.
class _DicaDoDia extends StatelessWidget {
  const _DicaDoDia();

  static const _dicas = [
    'Mantenha os dados de contato dos alunos sempre atualizados — isso facilita cobranças e avisos de aula.',
    'Registre pagamentos assim que forem recebidos, para o painel financeiro refletir a situação real da academia.',
    'Confira as pendências regularmente — elas concentram o que realmente precisa de ação hoje.',
    'Prefira inativar cadastros que saíram de uso, em vez de remover — assim o histórico da academia fica preservado.',
    'Aprove ou rejeite reposições pendentes rapidamente, para não deixar o aluno esperando uma resposta.',
    'Confira a matrícula (valor e vencimento) antes de renovar — é a última chance de ajustar algo específico daquele aluno.',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final indice = DateTime.now().toUtc().difference(DateTime.utc(2026)).inDays % _dicas.length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cardRaised,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(AppIcons.tip, size: 18, color: colors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
                  children: [
                    TextSpan(text: 'Dica do dia: ', style: TextStyle(color: colors.text, fontWeight: FontWeight.w700)),
                    TextSpan(text: _dicas[indice.abs()]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
