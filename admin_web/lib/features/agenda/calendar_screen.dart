import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

final _formatoDataIso = DateFormat('yyyy-MM-dd');

const _nomesDiaSemana = [
  'Domingo',
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
];
const _nomesDiaSemanaCurto = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
const _nomesMes = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

enum _ModoCalendario { dia, semana, mes }

DateTime _somenteData(DateTime data) => DateTime(data.year, data.month, data.day);

/// `[início, fim]` inclusivos da janela de consulta pro modo/data atuais.
(DateTime, DateTime) _janela(_ModoCalendario modo, DateTime referencia) {
  final dia = _somenteData(referencia);
  switch (modo) {
    case _ModoCalendario.dia:
      return (dia, dia);
    case _ModoCalendario.semana:
      // `weekday`: segunda=1 … domingo=7 — semana começa na segunda.
      final inicio = dia.subtract(Duration(days: dia.weekday - 1));
      return (inicio, inicio.add(const Duration(days: 6)));
    case _ModoCalendario.mes:
      final inicio = DateTime(referencia.year, referencia.month, 1);
      final fim = DateTime(referencia.year, referencia.month + 1, 0);
      return (inicio, fim);
  }
}

List<Aula> _aulasNoDia(List<Aula> aulas, DateTime dia) {
  return aulas.where((a) => a.data.year == dia.year && a.data.month == dia.month && a.data.day == dia.day).toList()
    ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
}

/// Sprint de UX da Agenda (docs/24, item 3) — ocupação é sempre **da
/// ocorrência** (`Aula.totalAlunos`/`capacidadeMaxima`), nunca a vaga
/// estrutural da Turma (essa continua em `TurmaDetailScreen`, via "Abrir
/// Turma"). Sem capacidade definida (ilimitada), não há o que colorir.
AppBadgeTone _tomOcupacao(int totalAlunos, int? capacidadeMaxima) {
  if (capacidadeMaxima == null || capacidadeMaxima == 0) return AppBadgeTone.neutral;
  final ocupacao = totalAlunos / capacidadeMaxima;
  if (ocupacao >= 1) return AppBadgeTone.error;
  if (ocupacao >= 0.7) return AppBadgeTone.warning;
  return AppBadgeTone.success;
}

String _rotuloOcupacao(int totalAlunos, int? capacidadeMaxima) {
  return capacidadeMaxima != null ? '$totalAlunos/$capacidadeMaxima' : '$totalAlunos aluno(s)';
}

/// Mesmo parser de `modalidades_screen.dart` (`_corDeHex`) — duplicado de
/// propósito em vez de extraído pro Design System: são 6 linhas usadas em
/// 2 telas, não justifica um utilitário compartilhado ainda.
Color? _corDeHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final limpo = hex.replaceFirst('#', '');
  final valor = int.tryParse(limpo, radix: 16);
  if (valor == null) return null;
  return Color(0xFF000000 | valor);
}

/// Calendário — Módulo 4 (MS7), uma **visão operacional sobre `Aula`**,
/// nunca uma entidade própria (docs/18, seção 5, "Calendário"): esta tela
/// só organiza e apresenta `Aula`s já existentes, com os 4 filtros já
/// previstos desde a análise (`turmaId`/`professorId`/`modalidadeId`/
/// `status`). Ao tocar numa Aula, abre `_AulaAcoesDialog` (visualizar,
/// cancelar, definir substituto) — mesmo padrão de diálogo contextual já
/// consolidado, sem tela de detalhe própria pra Aula. Nenhum componente
/// novo do Design System — dia/semana/mês são composições locais de
/// `AppCard`/`AppButton`/`AppBadge`/`Divider` já existentes.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  _ModoCalendario _modo = _ModoCalendario.semana;
  DateTime _dataReferencia = _somenteData(DateTime.now());

  String? _turmaIdFiltro;
  String? _professorIdFiltro;
  String? _modalidadeIdFiltro;
  AulaStatus? _statusFiltro;

  List<Turma> _turmas = [];
  List<Professor> _professores = [];
  List<Modalidade> _modalidades = [];
  bool _carregandoFiltros = true;

  Future<List<Aula>>? _future;

  @override
  void initState() {
    super.initState();
    _carregarFiltros();
  }

  Future<void> _carregarFiltros() async {
    try {
      final turmasFuture = ref.read(turmasApiProvider).list(status: UserStatus.ativo, pageSize: 100);
      final professoresFuture = ref.read(professoresApiProvider).list(status: UserStatus.ativo, pageSize: 100);
      final modalidadesFuture = ref.read(modalidadesApiProvider).list(status: UserStatus.ativo, pageSize: 100);
      _turmas = (await turmasFuture).items;
      _professores = (await professoresFuture).items;
      _modalidades = (await modalidadesFuture).items;
    } finally {
      if (mounted) setState(() => _carregandoFiltros = false);
    }
    _carregar();
  }

  void _carregar() {
    final (inicio, fim) = _janela(_modo, _dataReferencia);
    setState(() {
      _future = ref
          .read(aulasApiProvider)
          .listCalendario(
            dataInicio: _formatoDataIso.format(inicio),
            dataFim: _formatoDataIso.format(fim),
            turmaId: _turmaIdFiltro,
            professorId: _professorIdFiltro,
            modalidadeId: _modalidadeIdFiltro,
            status: _statusFiltro,
            pageSize: 200,
          )
          .then((resultado) => resultado.items);
    });
  }

  /// Sprint de UX da Agenda (docs/24, item 1) — `_turmas`/`_modalidades` já
  /// são carregadas pro filtro; reaproveitadas aqui pra derivar, sem
  /// consulta nova, se uma Aula tem professor substituto (≠ titular da
  /// Turma) e a cor da Modalidade (identificação visual do chip).
  Turma? _turmaDe(String turmaId) {
    for (final turma in _turmas) {
      if (turma.id == turmaId) return turma;
    }
    return null;
  }

  Color? _corModalidade(String modalidadeId) {
    for (final modalidade in _modalidades) {
      if (modalidade.id == modalidadeId) return _corDeHex(modalidade.cor);
    }
    return null;
  }

  void _mudarModo(_ModoCalendario modo) {
    setState(() => _modo = modo);
    _carregar();
  }

  void _navegar(int direcao) {
    setState(() {
      switch (_modo) {
        case _ModoCalendario.dia:
          _dataReferencia = _dataReferencia.add(Duration(days: direcao));
        case _ModoCalendario.semana:
          _dataReferencia = _dataReferencia.add(Duration(days: 7 * direcao));
        case _ModoCalendario.mes:
          _dataReferencia = DateTime(_dataReferencia.year, _dataReferencia.month + direcao, 1);
      }
    });
    _carregar();
  }

  void _irParaHoje() {
    setState(() => _dataReferencia = _somenteData(DateTime.now()));
    _carregar();
  }

  Future<void> _abrirAcoes(Aula aula) async {
    final alterou = await showDialog<bool>(
      context: context,
      builder: (_) => _AulaAcoesDialog(aula: aula, professores: _professores, turma: _turmaDe(aula.turmaId)),
    );
    if (alterou == true) _carregar();
  }

  Future<void> _novaAulaExtra() async {
    final criada = await showDialog<bool>(
      context: context,
      builder: (_) => _NovaAulaExtraDialog(
        turmas: _turmas,
        professores: _professores,
        dataInicial: _dataReferencia,
      ),
    );
    if (criada == true) _carregar();
  }

  String get _rotuloJanela {
    final (inicio, fim) = _janela(_modo, _dataReferencia);
    switch (_modo) {
      case _ModoCalendario.dia:
        return '${_nomesDiaSemana[inicio.weekday % 7]}, ${dataCurtaFormat.format(inicio)}';
      case _ModoCalendario.semana:
        return '${dataCurtaFormat.format(inicio)} – ${dataCurtaFormat.format(fim)}';
      case _ModoCalendario.mes:
        return '${_nomesMes[_dataReferencia.month - 1]} de ${_dataReferencia.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calendário', style: AppTypography.displayLarge.copyWith(color: colors.text)),
            const SizedBox(height: AppSpacing.xl),
            _barraDeControles(colors),
            const SizedBox(height: AppSpacing.lg),
            _barraDeFiltros(),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: FutureBuilder<List<Aula>>(
                future: _future,
                builder: (context, snapshot) {
                  if (_carregandoFiltros || snapshot.connectionState == ConnectionState.waiting) {
                    return const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LoadingSkeleton(width: double.infinity, height: 16),
                        SizedBox(height: AppSpacing.sm),
                        LoadingSkeleton(width: double.infinity, height: 16),
                        SizedBox(height: AppSpacing.sm),
                        LoadingSkeleton(width: double.infinity, height: 16),
                      ],
                    );
                  }
                  if (snapshot.hasError) {
                    return EmptyState(
                      icon: AppIcons.alert,
                      title: 'Não foi possível carregar o calendário.',
                      actionLabel: 'Tentar novamente',
                      onAction: _carregar,
                    );
                  }
                  final aulas = snapshot.data!;
                  if (aulas.isEmpty) {
                    return EmptyState(
                      icon: AppIcons.calendar,
                      title: 'Nenhuma aula neste período',
                      description: 'Ajuste os filtros ou gere aulas a partir de uma Turma.',
                      actionLabel: 'Nova aula extra',
                      onAction: _novaAulaExtra,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _resumoOperacional(aulas),
                      const SizedBox(height: AppSpacing.lg),
                      switch (_modo) {
                        _ModoCalendario.dia => _visaoDia(aulas),
                        _ModoCalendario.semana => _visaoSemana(aulas),
                        _ModoCalendario.mes => _visaoMes(aulas),
                      },
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barraDeControles(AppColorScheme colors) {
    final modoToggle = Wrap(
      spacing: AppSpacing.xs,
      children: [
        for (final modo in _ModoCalendario.values)
          AppButton(
            label: switch (modo) {
              _ModoCalendario.dia => 'Dia',
              _ModoCalendario.semana => 'Semana',
              _ModoCalendario.mes => 'Mês',
            },
            variant: _modo == modo ? AppButtonVariant.primary : AppButtonVariant.outline,
            onPressed: () => _mudarModo(modo),
          ),
      ],
    );

    final navegacao = Wrap(
      spacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _StepButton(icon: AppIcons.chevronLeft, onTap: () => _navegar(-1)),
        AppButton(label: 'Hoje', variant: AppButtonVariant.secondary, onPressed: _irParaHoje),
        _StepButton(icon: AppIcons.chevronRight, onTap: () => _navegar(1)),
        const SizedBox(width: AppSpacing.sm),
        Text(_rotuloJanela, style: AppTypography.titleMedium.copyWith(color: colors.text)),
      ],
    );

    if (context.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          modoToggle,
          const SizedBox(height: AppSpacing.md),
          navegacao,
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Nova aula extra', icon: AppIcons.add, onPressed: _novaAulaExtra),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        modoToggle,
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: navegacao),
        AppButton(label: 'Nova aula extra', icon: AppIcons.add, onPressed: _novaAulaExtra),
      ],
    );
  }

  bool get _temFiltroAtivo =>
      _turmaIdFiltro != null ||
      _professorIdFiltro != null ||
      _modalidadeIdFiltro != null ||
      _statusFiltro != null;

  void _limparFiltros() {
    setState(() {
      _turmaIdFiltro = null;
      _professorIdFiltro = null;
      _modalidadeIdFiltro = null;
      _statusFiltro = null;
    });
    _carregar();
  }

  Widget _barraDeFiltros() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 200,
          child: AppSelect<String?>(
            label: 'Turma',
            value: _turmaIdFiltro,
            options: [
              const AppSelectOption(value: null, label: 'Todas as turmas'),
              for (final turma in _turmas) AppSelectOption(value: turma.id, label: turma.nome),
            ],
            onChanged: (v) {
              setState(() => _turmaIdFiltro = v);
              _carregar();
            },
          ),
        ),
        SizedBox(
          width: 200,
          child: AppSelect<String?>(
            label: 'Professor',
            value: _professorIdFiltro,
            options: [
              const AppSelectOption(value: null, label: 'Todos os professores'),
              for (final professor in _professores) AppSelectOption(value: professor.id, label: professor.nome),
            ],
            onChanged: (v) {
              setState(() => _professorIdFiltro = v);
              _carregar();
            },
          ),
        ),
        SizedBox(
          width: 200,
          child: AppSelect<String?>(
            label: 'Modalidade',
            value: _modalidadeIdFiltro,
            options: [
              const AppSelectOption(value: null, label: 'Todas as modalidades'),
              for (final modalidade in _modalidades) AppSelectOption(value: modalidade.id, label: modalidade.nome),
            ],
            onChanged: (v) {
              setState(() => _modalidadeIdFiltro = v);
              _carregar();
            },
          ),
        ),
        SizedBox(
          width: 170,
          child: AppSelect<AulaStatus?>(
            label: 'Status',
            value: _statusFiltro,
            options: const [
              AppSelectOption(value: null, label: 'Todos os status'),
              AppSelectOption(value: AulaStatus.agendada, label: 'Agendada'),
              AppSelectOption(value: AulaStatus.cancelada, label: 'Cancelada'),
            ],
            onChanged: (v) {
              setState(() => _statusFiltro = v);
              _carregar();
            },
          ),
        ),
        if (_temFiltroAtivo)
          AppButton(
            label: 'Limpar filtros',
            variant: AppButtonVariant.ghost,
            onPressed: _limparFiltros,
          ),
      ],
    );
  }

  /// Resumo operacional (docs/24, item 6) — sempre sobre o período
  /// **atualmente visível** (não "hoje" fixo), pra nunca ficar descolado
  /// do que está na grade abaixo; some rótulo com `_rotuloJanela`, que já
  /// existe pra cabeçalho de navegação. Tudo calculado sobre a lista de
  /// Aulas já carregada — nenhuma consulta adicional.
  Widget _resumoOperacional(List<Aula> aulas) {
    final colors = context.colors;
    final totalAlunos = aulas.fold<int>(0, (soma, a) => soma + a.totalAlunos);
    final cancelamentos = aulas.where((a) => a.status == AulaStatus.cancelada).length;
    final reposicoes = aulas.fold<int>(0, (soma, a) => soma + a.totalReposicoes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resumo · $_rotuloJanela', style: AppTypography.labelSmall.copyWith(color: colors.textFaint)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            MetricCard(label: 'Aulas', value: '${aulas.length}', width: 150),
            MetricCard(label: 'Alunos previstos', value: '$totalAlunos', width: 150),
            MetricCard(label: 'Cancelamentos', value: '$cancelamentos', width: 150),
            MetricCard(label: 'Reposições', value: '$reposicoes', width: 150),
          ],
        ),
      ],
    );
  }

  Widget _visaoDia(List<Aula> aulas) {
    final colors = context.colors;
    final doDia = _aulasNoDia(aulas, _dataReferencia);
    if (doDia.isEmpty) {
      return EmptyState(
        icon: AppIcons.calendar,
        title: 'Nenhuma aula neste dia',
        actionLabel: 'Nova aula extra',
        onAction: _novaAulaExtra,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < doDia.length; i++) ...[
          if (i > 0) Divider(color: colors.borderSoft, height: 1),
          _AulaListRow(
            aula: doDia[i],
            onTap: () => _abrirAcoes(doDia[i]),
            substituto: _ehSubstituto(doDia[i]),
          ),
        ],
      ],
    );
  }

  /// Verdadeiro só quando a Turma é conhecida e o professor da ocorrência
  /// diverge do titular — nunca assume substituição por falta de dado.
  bool _ehSubstituto(Aula aula) {
    final turma = _turmaDe(aula.turmaId);
    return turma != null && turma.professorId != aula.professorId;
  }

  Widget _visaoSemana(List<Aula> aulas) {
    final colors = context.colors;
    final (inicio, _) = _janela(_ModoCalendario.semana, _dataReferencia);
    final dias = [for (var i = 0; i < 7; i++) inicio.add(Duration(days: i))];
    final hoje = _somenteData(DateTime.now());

    if (context.isMobile) {
      return Column(
        children: [
          for (var i = 0; i < dias.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            _ColunaDia(
              dia: dias[i],
              destacado: dias[i] == hoje,
              aulas: _aulasNoDia(aulas, dias[i]),
              onTapAula: _abrirAcoes,
              ehSubstituto: _ehSubstituto,
              resolveCorModalidade: _corModalidade,
            ),
          ],
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < dias.length; i++) ...[
            if (i > 0) VerticalDivider(color: colors.borderSoft, width: 1),
            Expanded(
              child: _ColunaDia(
                dia: dias[i],
                destacado: dias[i] == hoje,
                aulas: _aulasNoDia(aulas, dias[i]),
                onTapAula: _abrirAcoes,
                ehSubstituto: _ehSubstituto,
                resolveCorModalidade: _corModalidade,
                compacta: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _visaoMes(List<Aula> aulas) {
    final colors = context.colors;
    final primeiroDia = DateTime(_dataReferencia.year, _dataReferencia.month, 1);
    final ultimoDia = DateTime(_dataReferencia.year, _dataReferencia.month + 1, 0);
    final inicioGrade = primeiroDia.subtract(Duration(days: primeiroDia.weekday - 1));
    final fimGrade = ultimoDia.add(Duration(days: 7 - ultimoDia.weekday));
    final dias = <DateTime>[];
    for (var cursor = inicioGrade; !cursor.isAfter(fimGrade); cursor = cursor.add(const Duration(days: 1))) {
      dias.add(cursor);
    }
    final hoje = _somenteData(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final nome in _nomesDiaSemanaCurto)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Text(
                    nome,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall.copyWith(color: colors.textFaint),
                  ),
                ),
              ),
          ],
        ),
        Divider(color: colors.borderSoft, height: 1),
        for (var semana = 0; semana * 7 < dias.length; semana++) ...[
          if (semana > 0) Divider(color: colors.borderSoft, height: 1),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = semana * 7; i < semana * 7 + 7; i++) ...[
                  if (i > semana * 7) VerticalDivider(color: colors.borderSoft, width: 1),
                  Expanded(
                    child: _CelulaMes(
                      dia: dias[i],
                      noMesAtual: dias[i].month == _dataReferencia.month,
                      destacado: dias[i] == hoje,
                      aulas: _aulasNoDia(aulas, dias[i]),
                      onTapAula: _abrirAcoes,
                      onVerMais: (dia) {
                        setState(() {
                          _modo = _ModoCalendario.dia;
                          _dataReferencia = dia;
                        });
                        _carregar();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        hoverColor: colors.cardRaised,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(AppRadius.sm)),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: colors.textMuted),
        ),
      ),
    );
  }
}

class _AulaListRow extends StatelessWidget {
  const _AulaListRow({required this.aula, required this.onTap, required this.substituto});

  final Aula aula;
  final VoidCallback onTap;

  /// Verdadeiro quando o professor da ocorrência diverge do titular da
  /// Turma (docs/24, item 1) — calculado no cliente, sem consulta nova.
  final bool substituto;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final agendada = aula.status == AulaStatus.agendada;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        hoverColor: colors.cardRaised,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
          child: Row(
            children: [
              Icon(AppIcons.attendance, size: 16, color: colors.textFaint),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${aula.horaInicio} · ${aula.turmaNome}',
                      style: AppTypography.titleMedium.copyWith(
                        color: colors.text,
                        decoration: agendada ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    Text(
                      aula.local != null
                          ? '${aula.modalidadeNome} · ${aula.professorNome} · ${aula.local}'
                          : '${aula.modalidadeNome} · ${aula.professorNome}',
                      style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (substituto) const AppBadge('Substituto', tone: AppBadgeTone.warning),
                  if (!agendada)
                    const AppBadge('Cancelada', tone: AppBadgeTone.error)
                  else
                    AppBadge(
                      _rotuloOcupacao(aula.totalAlunos, aula.capacidadeMaxima),
                      tone: _tomOcupacao(aula.totalAlunos, aula.capacidadeMaxima),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Coluna de um dia — reutilizada pela visão semana (uma de 7, lado a
/// lado) e, empilhada, pela visão semana no mobile.
class _ColunaDia extends StatelessWidget {
  const _ColunaDia({
    required this.dia,
    required this.destacado,
    required this.aulas,
    required this.onTapAula,
    required this.ehSubstituto,
    required this.resolveCorModalidade,
    this.compacta = false,
  });

  final DateTime dia;
  final bool destacado;
  final List<Aula> aulas;
  final ValueChanged<Aula> onTapAula;
  final bool Function(Aula aula) ehSubstituto;
  final Color? Function(String modalidadeId) resolveCorModalidade;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compacta ? AppSpacing.sm : 0, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                _nomesDiaSemanaCurto[dia.weekday % 7],
                style: AppTypography.labelSmall.copyWith(color: colors.textFaint),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                decoration: destacado
                    ? BoxDecoration(color: colors.primaryWash, borderRadius: BorderRadius.circular(AppRadius.sm))
                    : null,
                child: Text(
                  '${dia.day}',
                  style: AppTypography.titleMedium.copyWith(
                    color: destacado ? colors.primaryStrong : colors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (aulas.isEmpty)
            Text('—', style: AppTypography.bodySmall.copyWith(color: colors.textFaint))
          else
            for (final aula in aulas)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _ChipAula(
                  aula: aula,
                  onTap: () => onTapAula(aula),
                  detalhado: true,
                  corModalidade: resolveCorModalidade(aula.modalidadeId),
                  substituto: ehSubstituto(aula),
                ),
              ),
        ],
      ),
    );
  }
}

class _CelulaMes extends StatelessWidget {
  const _CelulaMes({
    required this.dia,
    required this.noMesAtual,
    required this.destacado,
    required this.aulas,
    required this.onTapAula,
    required this.onVerMais,
  });

  final DateTime dia;
  final bool noMesAtual;
  final bool destacado;
  final List<Aula> aulas;
  final ValueChanged<Aula> onTapAula;
  final ValueChanged<DateTime> onVerMais;

  static const _maxVisiveis = 3;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final visiveis = aulas.take(_maxVisiveis).toList();
    final restantes = aulas.length - visiveis.length;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            decoration: destacado
                ? BoxDecoration(color: colors.primaryWash, borderRadius: BorderRadius.circular(AppRadius.sm))
                : null,
            child: Text(
              '${dia.day}',
              style: AppTypography.bodyMedium.copyWith(
                color: destacado
                    ? colors.primaryStrong
                    : noMesAtual
                    ? colors.text
                    : colors.textFaint,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final aula in visiveis)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _ChipAula(aula: aula, onTap: () => onTapAula(aula)),
            ),
          if (restantes > 0)
            InkWell(
              onTap: () => onVerMais(dia),
              child: Text(
                '+$restantes mais',
                style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChipAula extends StatelessWidget {
  const _ChipAula({
    required this.aula,
    required this.onTap,
    this.detalhado = false,
    this.corModalidade,
    this.substituto = false,
  });

  final Aula aula;
  final VoidCallback onTap;

  /// Semana mostra professor/ocupação/substituição; Mês (`_CelulaMes`)
  /// continua minimalista de propósito (docs/23/24 — "Mês é estratégico",
  /// leitura densa por célula piora mais do que ajuda no planejamento).
  final bool detalhado;

  /// Identificação visual da Modalidade (docs/24, item 1) — cor já
  /// carregada em `_modalidades`, sem consulta nova.
  final Color? corModalidade;

  /// Professor da ocorrência diverge do titular da Turma — calculado no
  /// cliente (docs/24, item 1).
  final bool substituto;

  Color _corDoTom(AppColorScheme colors, AppBadgeTone tom) => switch (tom) {
    AppBadgeTone.success => colors.success,
    AppBadgeTone.warning => colors.warning,
    AppBadgeTone.error => colors.error,
    _ => colors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final agendada = aula.status == AulaStatus.agendada;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: agendada ? colors.successWash : colors.cardRaised,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: corModalidade != null
              ? Border(left: BorderSide(color: corModalidade!, width: 3))
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${aula.horaInicio} ${aula.turmaNome}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: agendada ? colors.success : colors.textMuted,
                  decoration: agendada ? null : TextDecoration.lineThrough,
                ),
              ),
              if (detalhado)
                Text(
                  !agendada
                      ? 'Cancelada'
                      : substituto
                      ? '${aula.professorNome} · substituto'
                      : '${aula.professorNome} · ${_rotuloOcupacao(aula.totalAlunos, aula.capacidadeMaxima)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 10,
                    color: !agendada
                        ? colors.textFaint
                        : substituto
                        ? colors.warning
                        : _corDoTom(colors, _tomOcupacao(aula.totalAlunos, aula.capacidadeMaxima)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AcaoAulaView { menu, cancelar, substituto, frequencia }

/// Só aulas realizadas recebem presença (docs/18, seção 5, "Frequência —
/// invariante 3") — mesmo cálculo de "realizada" usado em toda a Agenda,
/// nunca armazenado: `status == AGENDADA && data < hoje`.
bool _aulaRealizada(Aula aula) {
  return aula.status == AulaStatus.agendada && aula.data.isBefore(_somenteData(DateTime.now()));
}

/// Diálogo operacional de uma Aula — visualizar/cancelar/definir
/// substituto/registrar frequência, mesmo chassi multi-view de
/// `_AcoesRecorrenciaDialog`. Nenhuma tela de detalhe própria (docs/18,
/// "Calendário"): tudo aqui.
class _AulaAcoesDialog extends ConsumerStatefulWidget {
  const _AulaAcoesDialog({required this.aula, required this.professores, required this.turma});

  final Aula aula;
  final List<Professor> professores;

  /// Nulo só se a Turma não estiver entre as ativas já carregadas pro
  /// filtro (caso raro) — "Abrir Turma" e o indicador de substituto ficam
  /// escondidos nesse caso, em vez de assumir dado que não se tem certeza.
  final Turma? turma;

  @override
  ConsumerState<_AulaAcoesDialog> createState() => _AulaAcoesDialogState();
}

class _AulaAcoesDialogState extends ConsumerState<_AulaAcoesDialog> {
  _AcaoAulaView _view = _AcaoAulaView.menu;
  final _motivoController = TextEditingController();
  String? _professorSubstitutoId;
  bool _salvando = false;
  bool _removendo = false;
  String? _erro;

  Future<List<AulaAluno>>? _alunosFuture;
  String? _erroFrequencia;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  void _abrirFrequencia() {
    setState(() {
      _view = _AcaoAulaView.frequencia;
      _alunosFuture = ref.read(aulaAlunosApiProvider).listPorAula(widget.aula.id);
    });
  }

  Future<void> _registrarPresenca(AulaAluno aulaAluno, PresencaStatus? presenca) async {
    if (presenca == null) return;
    setState(() => _erroFrequencia = null);
    try {
      await ref.read(aulaAlunosApiProvider).registrarPresenca(widget.aula.id, aulaAluno.id, presenca);
      setState(() {
        _alunosFuture = ref.read(aulaAlunosApiProvider).listPorAula(widget.aula.id);
      });
    } on DioException catch (e) {
      setState(() => _erroFrequencia = mensagemErroApi(e));
    }
  }

  /// Origem elegível pro lado do frontend (docs/21, decisão 2) — mesma
  /// regra validada de novo no backend, que é a autoridade final (409/400
  /// se algo mudou entre o carregamento da lista e o clique).
  bool _podeSolicitarReposicao(AulaAluno aulaAluno, bool aulaCancelada) {
    if (aulaCancelada) return true;
    return aulaAluno.presenca == PresencaStatus.ausente || aulaAluno.presenca == PresencaStatus.justificada;
  }

  Future<void> _abrirNovaSolicitacao(AulaAluno aulaAluno) async {
    final criada = await showDialog<bool>(
      context: context,
      builder: (_) => _NovaSolicitacaoReposicaoDialog(aulaAluno: aulaAluno),
    );
    if (criada == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solicitação de reposição registrada para ${aulaAluno.alunoNome}.')),
      );
    }
  }

  Future<void> _cancelar() async {
    setState(() => _erro = null);
    setState(() => _salvando = true);
    try {
      await ref.read(aulasApiProvider).cancelar(
            widget.aula.id,
            motivoCancelamento: _motivoController.text.trim().isEmpty ? null : _motivoController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _salvarSubstituto() async {
    setState(() => _erro = null);
    if (_professorSubstitutoId == null) {
      setState(() => _erro = 'Selecione o professor substituto');
      return;
    }
    setState(() => _salvando = true);
    try {
      await ref.read(aulasApiProvider).definirSubstituto(widget.aula.id, _professorSubstitutoId!);
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _remover() async {
    final confirmou = await AppConfirmDialog.show(
      context,
      variant: AppConfirmDialogVariant.danger,
      title: 'Remover aula',
      description:
          'Remover esta aula do cadastro? Use isto só para corrigir um lançamento feito por engano — '
          'para desmarcar a aula normalmente, use "Cancelar aula" em vez de remover.',
      confirmLabel: 'Remover',
    );
    if (confirmou != true || !mounted) return;

    setState(() => _removendo = true);
    try {
      await ref.read(aulasApiProvider).remove(widget.aula.id);
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (mounted) setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _removendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final aula = widget.aula;

    return Dialog(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: colors.border)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${dataCurtaFormat.format(aula.data)} · ${aula.horaInicio}',
                style: AppTypography.titleLarge.copyWith(color: colors.text),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(aula.turmaNome, style: AppTypography.bodyMedium.copyWith(color: colors.textMuted)),
              const SizedBox(height: AppSpacing.lg),
              if (_view == _AcaoAulaView.menu) ..._menu(colors),
              if (_view == _AcaoAulaView.cancelar) ..._formCancelar(),
              if (_view == _AcaoAulaView.substituto) ..._formSubstituto(),
              if (_view == _AcaoAulaView.frequencia) ..._viewFrequencia(colors),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _menu(AppColorScheme colors) {
    final aula = widget.aula;
    final agendada = aula.status == AulaStatus.agendada;
    final substituto = widget.turma != null && widget.turma!.professorId != aula.professorId;

    return [
      // Sprint de UX da Agenda (docs/24, item 4) — indicadores mais claros:
      // status/ocupação/substituição viram badges coloridas logo no topo,
      // em vez de só texto simples mais abaixo.
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          AppBadge(
            agendada ? 'Agendada' : 'Cancelada',
            tone: agendada ? AppBadgeTone.success : AppBadgeTone.error,
          ),
          if (agendada)
            AppBadge(
              _rotuloOcupacao(aula.totalAlunos, aula.capacidadeMaxima),
              tone: _tomOcupacao(aula.totalAlunos, aula.capacidadeMaxima),
            ),
          if (substituto) const AppBadge('Substituto', tone: AppBadgeTone.warning),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      AppFormRow(children: [
        AppDetailRow(label: 'Modalidade', value: aula.modalidadeNome),
        AppDetailRow(label: 'Professor', value: aula.professorNome),
      ]),
      const SizedBox(height: AppSpacing.md),
      AppFormRow(children: [
        AppDetailRow(label: 'Duração', value: '${aula.duracaoMinutos} min'),
        AppDetailRow(
          label: 'Capacidade',
          value: aula.capacidadeMaxima != null ? '${aula.capacidadeMaxima}' : 'Ilimitada',
        ),
      ]),
      if (aula.local != null) ...[
        const SizedBox(height: AppSpacing.md),
        AppDetailRow(label: 'Local', value: aula.local),
      ],
      if (!agendada && aula.motivoCancelamento != null) ...[
        const SizedBox(height: AppSpacing.md),
        AppDetailRow(label: 'Motivo do cancelamento', value: aula.motivoCancelamento),
      ],
      const SizedBox(height: AppSpacing.lg),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          if (widget.turma != null)
            AppButton(
              label: 'Abrir Turma',
              icon: AppIcons.turmas,
              variant: AppButtonVariant.ghost,
              onPressed: () {
                final turmaId = widget.turma!.id;
                Navigator.of(context).pop(false);
                context.go('/agenda/turmas/$turmaId');
              },
            ),
          if (agendada) ...[
            AppButton(
              label: 'Definir substituto',
              icon: AppIcons.teachers,
              variant: AppButtonVariant.secondary,
              onPressed: () => setState(() => _view = _AcaoAulaView.substituto),
            ),
            AppButton(
              label: 'Cancelar aula',
              icon: AppIcons.block,
              variant: AppButtonVariant.danger,
              onPressed: () => setState(() => _view = _AcaoAulaView.cancelar),
            ),
          ],
          if (_aulaRealizada(aula))
            AppButton(
              label: 'Registrar frequência',
              icon: AppIcons.attendance,
              variant: AppButtonVariant.secondary,
              onPressed: _abrirFrequencia,
            ),
          // Sprint 6 (Agenda Avançada) — origem de reposição também pode
          // ser uma aula cancelada (docs/21, decisão 2), que nunca passa
          // por `_aulaRealizada` (status != agendada). Reaproveita a mesma
          // view/mecanismo de "Registrar frequência" — dentro dela, o
          // seletor de presença some quando a aula está cancelada.
          if (!agendada)
            AppButton(
              label: 'Ver alunos / Solicitar reposição',
              icon: AppIcons.reposicao,
              variant: AppButtonVariant.secondary,
              onPressed: _abrirFrequencia,
            ),
          AppButton(
            label: 'Remover',
            icon: AppIcons.trash,
            variant: AppButtonVariant.danger,
            loading: _removendo,
            onPressed: _remover,
          ),
        ],
      ),
      if (_erro != null) ...[
        const SizedBox(height: AppSpacing.md),
        AppFormErrorBanner(_erro!),
      ],
      const SizedBox(height: AppSpacing.lg),
      Align(
        alignment: Alignment.centerRight,
        child: AppButton(
          label: 'Fechar',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
    ];
  }

  List<Widget> _formCancelar() {
    return [
      Text(
        'A aula continua no histórico — só o status muda para "Cancelada".',
        style: AppTypography.bodySmall.copyWith(color: context.colors.textMuted),
      ),
      const SizedBox(height: AppSpacing.md),
      AppTextField(label: 'Motivo (opcional)', controller: _motivoController, maxLines: 2),
      if (_erro != null) ...[
        const SizedBox(height: AppSpacing.md),
        AppFormErrorBanner(_erro!),
      ],
      const SizedBox(height: AppSpacing.xl),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppButton(
            label: 'Voltar',
            variant: AppButtonVariant.secondary,
            onPressed: _salvando ? null : () => setState(() => _view = _AcaoAulaView.menu),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(label: 'Confirmar cancelamento', loading: _salvando, onPressed: _cancelar),
        ],
      ),
    ];
  }

  List<Widget> _formSubstituto() {
    return [
      AppSelect<String?>(
        label: 'Professor substituto',
        value: _professorSubstitutoId,
        options: [
          for (final professor in widget.professores)
            AppSelectOption(value: professor.id, label: professor.nome),
        ],
        onChanged: (v) => setState(() => _professorSubstitutoId = v),
      ),
      if (_erro != null) ...[
        const SizedBox(height: AppSpacing.md),
        AppFormErrorBanner(_erro!),
      ],
      const SizedBox(height: AppSpacing.xl),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppButton(
            label: 'Voltar',
            variant: AppButtonVariant.secondary,
            onPressed: _salvando ? null : () => setState(() => _view = _AcaoAulaView.menu),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(label: 'Salvar', loading: _salvando, onPressed: _salvarSubstituto),
        ],
      ),
    ];
  }

  /// Frequência (MS8) — chega aqui se `_aulaRealizada(aula)` (registrar
  /// presença) **ou** se `aula.status == cancelada` (Sprint 6, docs/21
  /// decisão 2 — origem de reposição também pode ser uma aula cancelada).
  /// Cada linha registra/altera a presença com um único `AppSelect` (mesma
  /// operação pras duas coisas, docs/18 "Frequência — invariante 4"), sem
  /// botão de salvar por linha — muda no `onChanged`, como uma planilha de
  /// chamada. O seletor de presença só aparece quando a aula não está
  /// cancelada (não faz sentido marcar presença de algo que nunca
  /// aconteceu); "Solicitar reposição" aparece quando a aula está
  /// cancelada ou o aluno já tem falta/falta justificada marcada.
  List<Widget> _viewFrequencia(AppColorScheme colors) {
    final aulaCancelada = widget.aula.status == AulaStatus.cancelada;

    return [
      FutureBuilder<List<AulaAluno>>(
        future: _alunosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LoadingSkeleton(width: double.infinity, height: 16),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(width: double.infinity, height: 16),
              ],
            );
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: AppIcons.alert,
              title: 'Não foi possível carregar os alunos.',
              actionLabel: 'Tentar novamente',
              onAction: _abrirFrequencia,
            );
          }
          final alunos = snapshot.data!;
          if (alunos.isEmpty) {
            return EmptyState(icon: AppIcons.enrollment, title: 'Nenhum aluno vinculado a esta aula');
          }
          return Column(
            children: [
              for (var i = 0; i < alunos.length; i++) ...[
                if (i > 0) Divider(color: colors.borderSoft, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(alunos[i].alunoNome, style: AppTypography.bodyMedium.copyWith(color: colors.text)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      if (_podeSolicitarReposicao(alunos[i], aulaCancelada))
                        IconButton(
                          icon: Icon(AppIcons.reposicao, size: 18, color: colors.textMuted),
                          tooltip: 'Solicitar reposição',
                          onPressed: () => _abrirNovaSolicitacao(alunos[i]),
                        ),
                      if (!aulaCancelada) ...[
                        const SizedBox(width: AppSpacing.sm),
                        SizedBox(
                          width: 170,
                          child: AppSelect<PresencaStatus?>(
                            label: 'Presença',
                            value: alunos[i].presenca,
                            options: const [
                              AppSelectOption(value: null, label: 'Não marcada'),
                              AppSelectOption(value: PresencaStatus.presente, label: 'Presente'),
                              AppSelectOption(value: PresencaStatus.ausente, label: 'Falta'),
                              AppSelectOption(value: PresencaStatus.justificada, label: 'Falta justificada'),
                            ],
                            onChanged: (v) => _registrarPresenca(alunos[i], v),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
      if (_erroFrequencia != null) ...[
        const SizedBox(height: AppSpacing.md),
        AppFormErrorBanner(_erroFrequencia!),
      ],
      const SizedBox(height: AppSpacing.lg),
      Align(
        alignment: Alignment.centerRight,
        child: AppButton(
          label: 'Voltar',
          variant: AppButtonVariant.secondary,
          onPressed: () => setState(() => _view = _AcaoAulaView.menu),
        ),
      ),
    ];
  }
}

/// Sprint 6 (Agenda Avançada) — a solicitação nasce só com a aula de
/// origem perdida (docs/21, decisão 3); sem escolher destino aqui — a
/// recepção escolhe na aprovação, na tela "Reposições".
class _NovaSolicitacaoReposicaoDialog extends ConsumerStatefulWidget {
  const _NovaSolicitacaoReposicaoDialog({required this.aulaAluno});

  final AulaAluno aulaAluno;

  @override
  ConsumerState<_NovaSolicitacaoReposicaoDialog> createState() => _NovaSolicitacaoReposicaoDialogState();
}

class _NovaSolicitacaoReposicaoDialogState extends ConsumerState<_NovaSolicitacaoReposicaoDialog> {
  final _observacoesController = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    setState(() => _erro = null);
    setState(() => _salvando = true);
    try {
      await ref.read(solicitacoesReposicaoApiProvider).criar(
            widget.aulaAluno.id,
            observacoes: _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Dialog(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: colors.border)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Solicitar reposição', style: AppTypography.titleLarge.copyWith(color: colors.text)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${widget.aulaAluno.alunoNome} — a aula de destino é escolhida na aprovação, na tela "Reposições".',
                style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(label: 'Observações (opcional)', controller: _observacoesController, maxLines: 2),
              if (_erro != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppFormErrorBanner(_erro!),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancelar',
                    variant: AppButtonVariant.secondary,
                    onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(label: 'Solicitar', loading: _salvando, onPressed: _confirmar),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Criação de aula extra — sempre independente de Recorrência (docs/18,
/// "Calendário — invariante 4"). Diálogo com seleção de Turma + data/
/// horário/duração + override opcional de professor/capacidade.
class _NovaAulaExtraDialog extends ConsumerStatefulWidget {
  const _NovaAulaExtraDialog({
    required this.turmas,
    required this.professores,
    required this.dataInicial,
  });

  final List<Turma> turmas;
  final List<Professor> professores;
  final DateTime dataInicial;

  @override
  ConsumerState<_NovaAulaExtraDialog> createState() => _NovaAulaExtraDialogState();
}

class _NovaAulaExtraDialogState extends ConsumerState<_NovaAulaExtraDialog> {
  final _formKey = GlobalKey<FormState>();
  final _horaInicioController = TextEditingController(text: '19:00');
  final _duracaoMinutosController = TextEditingController(text: '60');
  final _capacidadeMaximaController = TextEditingController();

  String? _turmaId;
  String? _professorId;
  late DateTime _data;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _data = widget.dataInicial;
  }

  @override
  void dispose() {
    _horaInicioController.dispose();
    _duracaoMinutosController.dispose();
    _capacidadeMaximaController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await ref.read(aulasApiProvider).criarExtra(
            turmaId: _turmaId!,
            data: _formatoDataIso.format(_data),
            horaInicio: _horaInicioController.text.trim(),
            duracaoMinutos: int.parse(_duracaoMinutosController.text.trim()),
            professorId: _professorId,
            capacidadeMaxima: _capacidadeMaximaController.text.trim().isEmpty
                ? null
                : int.parse(_capacidadeMaximaController.text.trim()),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aula extra criada com sucesso.')));
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Dialog(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: colors.border)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nova aula extra', style: AppTypography.titleLarge.copyWith(color: colors.text)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Uma aula avulsa, independente de recorrência.',
                    style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppSelect<String?>(
                    label: 'Turma',
                    value: _turmaId,
                    options: [for (final turma in widget.turmas) AppSelectOption(value: turma.id, label: turma.nome)],
                    onChanged: (v) => setState(() => _turmaId = v),
                    validator: (v) => v == null ? 'Selecione a turma' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppDateField(
                    label: 'Data',
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    value: _data,
                    onChanged: (v) => setState(() => _data = v!),
                    validator: (v) => v == null ? 'Informe a data' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppFormRow(children: [
                    AppTextField(
                      label: 'Hora de início',
                      controller: _horaInicioController,
                      validator: (v) {
                        final valido = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch((v ?? '').trim());
                        return valido ? null : 'Use o formato HH:mm';
                      },
                    ),
                    AppTextField(
                      label: 'Duração (min)',
                      controller: _duracaoMinutosController,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final numero = int.tryParse((v ?? '').trim());
                        if (numero == null || numero < 1) return 'Informe um número válido';
                        return null;
                      },
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  AppSelect<String?>(
                    label: 'Professor (opcional — usa o titular da turma se não escolher)',
                    value: _professorId,
                    options: [
                      const AppSelectOption(value: null, label: 'Usar professor titular da turma'),
                      for (final professor in widget.professores)
                        AppSelectOption(value: professor.id, label: professor.nome),
                    ],
                    onChanged: (v) => setState(() => _professorId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Capacidade máxima (opcional)',
                    hintText: 'Usa a capacidade da turma',
                    controller: _capacidadeMaximaController,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final numero = int.tryParse(v.trim());
                      if (numero == null || numero <= 0) return 'Informe um número válido';
                      return null;
                    },
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppFormErrorBanner(_erro!),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppButton(
                        label: 'Cancelar',
                        variant: AppButtonVariant.secondary,
                        onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppButton(label: 'Criar', loading: _salvando, onPressed: _salvar),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

