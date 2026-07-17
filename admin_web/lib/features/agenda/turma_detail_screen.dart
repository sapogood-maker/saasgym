import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

import '../../routing/back_navigation.dart';

const _nomesDiaSemana = [
  'Domingo',
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
];

/// Painel de detalhe da turma — Módulo 4 (MS3/MS4/MS5/MS6), mesmo padrão
/// consolidado por `PlanoDetailScreen`/`AlunoDetailScreen`: seções em
/// `AppCard`, pares rótulo/valor via `AppDetailRow`.
///
/// "Recorrências" (MS4), "Alunos matriculados" (MS5) e "Aulas" (MS6) são
/// gerenciadas aqui mesmo — sem tela/rota própria, mesmo padrão de
/// diálogo já estabelecido para Modalidade (docs/18, "Plano de
/// micro-sprints"). "Aulas" só gera/lista nesta fase — cancelamento e
/// professor substituto ficam pro MS7 (Calendário).
class TurmaDetailScreen extends ConsumerStatefulWidget {
  const TurmaDetailScreen({required this.turmaId, super.key});

  final String turmaId;

  @override
  ConsumerState<TurmaDetailScreen> createState() => _TurmaDetailScreenState();
}

class _TurmaDetailScreenState extends ConsumerState<TurmaDetailScreen> {
  Future<Turma>? _future;
  bool _alterado = false;
  bool _processandoStatus = false;
  bool _removendo = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _future = ref.read(turmasApiProvider).get(widget.turmaId);
    });
  }

  void _voltar([bool? alterado]) {
    context.backToList('/agenda/turmas', result: alterado ?? _alterado);
  }

  Future<void> _alternarStatus(Turma turma) async {
    setState(() => _processandoStatus = true);
    try {
      final novoStatus = turma.status == UserStatus.ativo ? UserStatus.inativo : UserStatus.ativo;
      await ref.read(turmasApiProvider).updateStatus(turma.id, novoStatus);
      _alterado = true;
      _carregar();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErroApi(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _processandoStatus = false);
      }
    }
  }

  Future<void> _excluir(Turma turma) async {
    final confirmou = await AppConfirmDialog.show(
      context,
      variant: AppConfirmDialogVariant.danger,
      title: 'Remover turma',
      description:
          'Remover ${turma.nome}? Reservado a corrigir um cadastro feito por engano — some da lista, '
          'mas nada é apagado permanentemente. Para uma turma que parou de acontecer de verdade, use '
          'Inativar em vez disto.',
      confirmLabel: 'Remover',
    );
    if (confirmou != true || !mounted) {
      return;
    }

    setState(() => _removendo = true);
    try {
      await ref.read(turmasApiProvider).remove(turma.id);
      if (mounted) {
        _voltar(true);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErroApi(e))));
      }
      if (mounted) {
        setState(() => _removendo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _voltar();
        }
      },
      // Rota fora do ShellRoute (tela cheia) — precisa do próprio Scaffold,
      // igual ao TurmaFormScreen.
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: FutureBuilder<Turma>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _TurmaPainelSkeleton(onBack: _voltar);
                }
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppBackLink(label: 'Turmas', onTap: _voltar),
                      const SizedBox(height: AppSpacing.lg),
                      EmptyState(
                        icon: AppIcons.alert,
                        title: 'Não foi possível carregar a turma.',
                        actionLabel: 'Tentar novamente',
                        onAction: _carregar,
                      ),
                    ],
                  );
                }
                return _painel(context, snapshot.data!);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _painel(BuildContext context, Turma turma) {
    final ativo = turma.status == UserStatus.ativo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDetailHeader(
          listLabel: 'Turmas',
          onBack: _voltar,
          title: turma.nome,
          trailing: AppBadge(
            ativo ? 'Ativa' : 'Inativa',
            tone: ativo ? AppBadgeTone.success : AppBadgeTone.neutral,
          ),
          actions: [
            AppButton(
              label: 'Editar',
              icon: AppIcons.edit,
              onPressed: (_processandoStatus || _removendo)
                  ? null
                  : () async {
                      final resultado = await context.push<bool>('/agenda/turmas/${turma.id}/editar');
                      if (resultado == true) {
                        _alterado = true;
                        _carregar();
                      }
                    },
            ),
            AppButton(
              label: ativo ? 'Inativar' : 'Reativar',
              icon: ativo ? AppIcons.block : AppIcons.circleCheck,
              variant: AppButtonVariant.secondary,
              loading: _processandoStatus,
              onPressed: _removendo ? null : () => _alternarStatus(turma),
            ),
            AppButton(
              label: 'Remover',
              icon: AppIcons.trash,
              variant: AppButtonVariant.danger,
              loading: _removendo,
              onPressed: _processandoStatus ? null : () => _excluir(turma),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          title: 'Dados da turma',
          child: Column(
            children: [
              AppFormRow(children: [
                AppDetailRow(label: 'Nome', value: turma.nome),
              ]),
              const SizedBox(height: AppSpacing.md),
              AppFormRow(children: [
                AppDetailRow(label: 'Modalidade', value: turma.modalidadeNome),
                AppDetailRow(label: 'Professor titular', value: turma.professorNome),
              ]),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Detalhes',
          child: AppFormRow(children: [
            AppDetailRow(
              label: 'Capacidade máxima',
              value: turma.capacidadeMaxima != null ? '${turma.capacidadeMaxima}' : 'Ilimitada',
            ),
            AppDetailRow(label: 'Local', value: turma.local),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        _RecorrenciasSection(turmaId: turma.id),
        const SizedBox(height: AppSpacing.lg),
        _AlunosMatriculadosSection(turmaId: turma.id, capacidadeMaxima: turma.capacidadeMaxima),
        const SizedBox(height: AppSpacing.lg),
        _AulasSection(turmaId: turma.id),
      ],
    );
  }
}

class _TurmaPainelSkeleton extends StatelessWidget {
  const _TurmaPainelSkeleton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppBackLink(label: 'Turmas', onTap: onBack),
        const SizedBox(height: AppSpacing.lg),
        const LoadingSkeleton(width: 220, height: 28),
        const SizedBox(height: AppSpacing.sm),
        const LoadingSkeleton(width: 90, height: 20),
        const SizedBox(height: AppSpacing.xl),
        const AppCard(title: 'Dados da turma', loading: true),
        const SizedBox(height: AppSpacing.lg),
        const AppCard(title: 'Detalhes', loading: true),
      ],
    );
  }
}


String _descricaoRecorrencia(Recorrencia recorrencia) {
  final horario = '${recorrencia.horaInicio} (${recorrencia.duracaoMinutos} min)';
  switch (recorrencia.tipo) {
    case RecorrenciaTipo.semanal:
      return '${_nomesDiaSemana[recorrencia.diaSemana!]} · $horario';
    case RecorrenciaTipo.mensal:
      return 'Dia ${recorrencia.diaDoMes} do mês · $horario';
    case RecorrenciaTipo.intervalada:
      return 'A cada ${recorrencia.intervaloDias} dias · $horario';
  }
}

/// Seção "Recorrências" do Detalhe da Turma — carrega e gerencia a lista
/// inteira embutida (sem paginação: cabe numa tela, mesmo raciocínio de
/// `RecorrenciasApi` não estender `CrudApi<T>`). Widget próprio (em vez de
/// inline em `_painel`) só para isolar o carregamento/estado de diálogo
/// sem poluir o estado do `TurmaDetailScreen`.
class _RecorrenciasSection extends ConsumerStatefulWidget {
  const _RecorrenciasSection({required this.turmaId});

  final String turmaId;

  @override
  ConsumerState<_RecorrenciasSection> createState() => _RecorrenciasSectionState();
}

class _RecorrenciasSectionState extends ConsumerState<_RecorrenciasSection> {
  Future<List<Recorrencia>>? _future;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _future = ref.read(recorrenciasApiProvider).list(widget.turmaId);
    });
  }

  Future<void> _nova() async {
    final criada = await showAppDialog<bool>(
      context,
      maxWidth: 460,
      builder: (_) => _RecorrenciaFormDialog(turmaId: widget.turmaId),
    );
    if (criada == true) _carregar();
  }

  Future<void> _abrirAcoes(Recorrencia recorrencia) async {
    final alterou = await showAppDialog<bool>(
      context,
      maxWidth: 460,
      builder: (_) => _AcoesRecorrenciaDialog(turmaId: widget.turmaId, recorrencia: recorrencia),
    );
    if (alterou == true) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Recorrências',
      actions: [AppButton(label: 'Nova recorrência', icon: AppIcons.add, onPressed: _nova)],
      child: FutureBuilder<List<Recorrencia>>(
        future: _future,
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
              title: 'Não foi possível carregar as recorrências.',
              actionLabel: 'Tentar novamente',
              onAction: _carregar,
            );
          }
          final recorrencias = snapshot.data!;
          if (recorrencias.isEmpty) {
            return EmptyState(
              icon: AppIcons.calendar,
              title: 'Nenhuma recorrência cadastrada',
              description: 'Cadastre os dias e horários em que esta turma acontece.',
              actionLabel: 'Nova recorrência',
              onAction: _nova,
            );
          }
          final colors = context.colors;
          return Column(
            children: [
              for (var i = 0; i < recorrencias.length; i++) ...[
                if (i > 0) Divider(color: colors.borderSoft, height: 1),
                _RecorrenciaRow(
                  recorrencia: recorrencias[i],
                  onTap: () => _abrirAcoes(recorrencias[i]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RecorrenciaRow extends StatelessWidget {
  const _RecorrenciaRow({required this.recorrencia, required this.onTap});

  final Recorrencia recorrencia;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final professor = recorrencia.professorNome != null
        ? 'Professor: ${recorrencia.professorNome}'
        : 'Professor titular da turma';
    final vigencia = recorrencia.dataFimVigencia != null
        ? ' · vigência ${dataCurtaFormat.format(recorrencia.dataInicioVigencia)} a ${dataCurtaFormat.format(recorrencia.dataFimVigencia!)}'
        : '';
    final subtitle = '$professor$vigencia';

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
              Icon(AppIcons.calendar, size: 16, color: colors.textFaint),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _descricaoRecorrencia(recorrencia),
                      style: AppTypography.titleMedium.copyWith(color: colors.text),
                    ),
                    Text(subtitle, style: AppTypography.bodySmall.copyWith(color: colors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppBadge(
                recorrencia.ativo ? 'Ativa' : 'Inativa',
                tone: recorrencia.ativo ? AppBadgeTone.success : AppBadgeTone.neutral,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formulário de criação de recorrência — diálogo (não rota própria,
/// mesmo padrão de `_NovaModalidadeDialog`). Só o campo relevante ao
/// `tipo` selecionado aparece (`diaSemana`/`diaDoMes`/`intervaloDias`),
/// espelhando a validação condicional do backend (docs/18, seção 2 item 3).
class _RecorrenciaFormDialog extends ConsumerStatefulWidget {
  const _RecorrenciaFormDialog({required this.turmaId});

  final String turmaId;

  @override
  ConsumerState<_RecorrenciaFormDialog> createState() => _RecorrenciaFormDialogState();
}

class _RecorrenciaFormDialogState extends ConsumerState<_RecorrenciaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _diaDoMesController = TextEditingController();
  final _intervaloDiasController = TextEditingController();
  final _horaInicioController = TextEditingController();
  final _duracaoMinutosController = TextEditingController();

  RecorrenciaTipo? _tipo;
  int? _diaSemana;
  String? _professorId;
  DateTime? _dataInicioVigencia;
  DateTime? _dataFimVigencia;

  List<Professor> _professores = [];
  bool _carregandoOpcoes = true;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _dataInicioVigencia = DateTime.now();
    _carregarOpcoes();
  }

  Future<void> _carregarOpcoes() async {
    try {
      final resultado = await ref.read(professoresApiProvider).list(status: UserStatus.ativo, pageSize: 100);
      _professores = resultado.items;
    } on DioException catch (e) {
      _erro = mensagemErroApi(e);
    } finally {
      if (mounted) setState(() => _carregandoOpcoes = false);
    }
  }

  @override
  void dispose() {
    _diaDoMesController.dispose();
    _intervaloDiasController.dispose();
    _horaInicioController.dispose();
    _duracaoMinutosController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _construirPayload() {
    return {
      'tipo': _tipo!.wireValue,
      if (_tipo == RecorrenciaTipo.semanal) 'diaSemana': _diaSemana,
      if (_tipo == RecorrenciaTipo.mensal) 'diaDoMes': int.parse(_diaDoMesController.text.trim()),
      if (_tipo == RecorrenciaTipo.intervalada)
        'intervaloDias': int.parse(_intervaloDiasController.text.trim()),
      'horaInicio': _horaInicioController.text.trim(),
      'duracaoMinutos': int.parse(_duracaoMinutosController.text.trim()),
      if (_professorId != null) 'professorId': _professorId,
      'dataInicioVigencia': DateFormat('yyyy-MM-dd').format(_dataInicioVigencia!),
      if (_dataFimVigencia != null) 'dataFimVigencia': DateFormat('yyyy-MM-dd').format(_dataFimVigencia!),
    };
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await ref.read(recorrenciasApiProvider).create(widget.turmaId, _construirPayload());
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

    return _carregandoOpcoes
        ? const SizedBox(
            height: 120,
            child: Center(child: LoadingSkeleton(width: 200, height: 16)),
          )
        : Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nova recorrência', style: AppTypography.titleLarge.copyWith(color: colors.text)),
                const SizedBox(height: AppSpacing.lg),
                AppSelect<RecorrenciaTipo?>(
                  label: 'Tipo',
                  value: _tipo,
                  options: const [
                    AppSelectOption(value: RecorrenciaTipo.semanal, label: 'Semanal'),
                    AppSelectOption(value: RecorrenciaTipo.mensal, label: 'Mensal'),
                    AppSelectOption(value: RecorrenciaTipo.intervalada, label: 'Intervalada'),
                  ],
                  onChanged: (v) => setState(() => _tipo = v),
                  validator: (v) => v == null ? 'Selecione o tipo' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                if (_tipo == RecorrenciaTipo.semanal)
                  AppSelect<int?>(
                    label: 'Dia da semana',
                    value: _diaSemana,
                    options: [
                      for (var i = 0; i < _nomesDiaSemana.length; i++)
                        AppSelectOption(value: i, label: _nomesDiaSemana[i]),
                    ],
                    onChanged: (v) => setState(() => _diaSemana = v),
                    validator: (v) => v == null ? 'Selecione o dia da semana' : null,
                  ),
                if (_tipo == RecorrenciaTipo.mensal)
                  AppTextField(
                    label: 'Dia do mês (1-31)',
                    controller: _diaDoMesController,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final numero = int.tryParse((v ?? '').trim());
                      if (numero == null || numero < 1 || numero > 31) {
                        return 'Informe um dia entre 1 e 31';
                      }
                      return null;
                    },
                  ),
                if (_tipo == RecorrenciaTipo.intervalada)
                  AppTextField(
                    label: 'Intervalo em dias',
                    hintText: '14',
                    controller: _intervaloDiasController,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final numero = int.tryParse((v ?? '').trim());
                      if (numero == null || numero < 1) return 'Informe um número válido';
                      return null;
                    },
                  ),
                if (_tipo != null) const SizedBox(height: AppSpacing.md),
                AppFormRow(children: [
                  AppTextField(
                    label: 'Hora de início',
                    hintText: '07:00',
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
                  label: 'Professor (opcional — substitui o titular só nesta recorrência)',
                  value: _professorId,
                  options: [
                    const AppSelectOption(value: null, label: 'Usar professor titular da turma'),
                    for (final professor in _professores)
                      AppSelectOption(value: professor.id, label: professor.nome),
                  ],
                  onChanged: (v) => setState(() => _professorId = v),
                ),
                const SizedBox(height: AppSpacing.md),
                AppFormRow(children: [
                  AppDateField(
                    label: 'Início da vigência',
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    value: _dataInicioVigencia,
                    onChanged: (v) => setState(() => _dataInicioVigencia = v),
                    validator: (v) => v == null ? 'Informe o início da vigência' : null,
                  ),
                  AppDateField(
                    label: 'Fim da vigência (opcional)',
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    value: _dataFimVigencia,
                    onChanged: (v) => setState(() => _dataFimVigencia = v),
                  ),
                ]),
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
                    AppButton(label: 'Salvar', loading: _salvando, onPressed: _salvar),
                  ],
                ),
              ],
            ),
          );
  }
}

enum _AcaoRecorrenciaView { menu, editar }

/// Ações rápidas de uma recorrência — editar, ativar/inativar, remover.
/// Mesmo chassi de `_AcoesModalidadeDialog`.
class _AcoesRecorrenciaDialog extends ConsumerStatefulWidget {
  const _AcoesRecorrenciaDialog({required this.turmaId, required this.recorrencia});

  final String turmaId;
  final Recorrencia recorrencia;

  @override
  ConsumerState<_AcoesRecorrenciaDialog> createState() => _AcoesRecorrenciaDialogState();
}

class _AcoesRecorrenciaDialogState extends ConsumerState<_AcoesRecorrenciaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _diaDoMesController;
  late final TextEditingController _intervaloDiasController;
  late final TextEditingController _horaInicioController;
  late final TextEditingController _duracaoMinutosController;

  _AcaoRecorrenciaView _view = _AcaoRecorrenciaView.menu;
  late RecorrenciaTipo _tipo;
  int? _diaSemana;
  String? _professorId;
  late DateTime _dataInicioVigencia;
  DateTime? _dataFimVigencia;

  List<Professor> _professores = [];
  bool _carregandoOpcoes = true;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final r = widget.recorrencia;
    _tipo = r.tipo;
    _diaSemana = r.diaSemana;
    _professorId = r.professorId;
    _dataInicioVigencia = r.dataInicioVigencia;
    _dataFimVigencia = r.dataFimVigencia;
    _diaDoMesController = TextEditingController(text: r.diaDoMes?.toString() ?? '');
    _intervaloDiasController = TextEditingController(text: r.intervaloDias?.toString() ?? '');
    _horaInicioController = TextEditingController(text: r.horaInicio);
    _duracaoMinutosController = TextEditingController(text: r.duracaoMinutos.toString());
    _carregarOpcoes();
  }

  Future<void> _carregarOpcoes() async {
    try {
      final resultado = await ref.read(professoresApiProvider).list(status: UserStatus.ativo, pageSize: 100);
      _professores = resultado.items;
    } on DioException catch (e) {
      _erro = mensagemErroApi(e);
    } finally {
      if (mounted) setState(() => _carregandoOpcoes = false);
    }
  }

  @override
  void dispose() {
    _diaDoMesController.dispose();
    _intervaloDiasController.dispose();
    _horaInicioController.dispose();
    _duracaoMinutosController.dispose();
    super.dispose();
  }

  Future<void> _salvarEdicao() async {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await ref.read(recorrenciasApiProvider).update(widget.turmaId, widget.recorrencia.id, {
        'tipo': _tipo.wireValue,
        if (_tipo == RecorrenciaTipo.semanal) 'diaSemana': _diaSemana,
        if (_tipo == RecorrenciaTipo.mensal) 'diaDoMes': int.parse(_diaDoMesController.text.trim()),
        if (_tipo == RecorrenciaTipo.intervalada)
          'intervaloDias': int.parse(_intervaloDiasController.text.trim()),
        'horaInicio': _horaInicioController.text.trim(),
        'duracaoMinutos': int.parse(_duracaoMinutosController.text.trim()),
        'professorId': _professorId,
        'dataInicioVigencia': DateFormat('yyyy-MM-dd').format(_dataInicioVigencia),
        if (_dataFimVigencia != null) 'dataFimVigencia': DateFormat('yyyy-MM-dd').format(_dataFimVigencia!),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _alternarAtivo() async {
    setState(() => _salvando = true);
    try {
      await ref
          .read(recorrenciasApiProvider)
          .update(widget.turmaId, widget.recorrencia.id, {'ativo': !widget.recorrencia.ativo});
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
      title: 'Remover recorrência',
      description: 'Remover esta recorrência? O histórico de aulas já geradas por ela é preservado.',
      confirmLabel: 'Remover',
    );
    if (confirmou != true || !mounted) return;

    setState(() => _salvando = true);
    try {
      await ref.read(recorrenciasApiProvider).remove(widget.turmaId, widget.recorrencia.id);
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (mounted) setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_descricaoRecorrencia(widget.recorrencia), style: AppTypography.titleLarge.copyWith(color: colors.text)),
        const SizedBox(height: AppSpacing.lg),
        if (_view == _AcaoRecorrenciaView.menu) ..._menu(),
        if (_view == _AcaoRecorrenciaView.editar) ..._formEditar(),
      ],
    );
  }

  List<Widget> _menu() {
    return [
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          AppButton(
            label: 'Editar',
            icon: AppIcons.edit,
            onPressed: _salvando ? null : () => setState(() => _view = _AcaoRecorrenciaView.editar),
          ),
          AppButton(
            label: widget.recorrencia.ativo ? 'Inativar' : 'Reativar',
            icon: widget.recorrencia.ativo ? AppIcons.block : AppIcons.circleCheck,
            variant: AppButtonVariant.secondary,
            loading: _salvando,
            onPressed: _alternarAtivo,
          ),
          AppButton(
            label: 'Remover',
            icon: AppIcons.trash,
            variant: AppButtonVariant.danger,
            loading: _salvando,
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

  List<Widget> _formEditar() {
    if (_carregandoOpcoes) {
      return const [
        SizedBox(height: 80, child: Center(child: LoadingSkeleton(width: 200, height: 16))),
      ];
    }
    return [
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSelect<RecorrenciaTipo?>(
              label: 'Tipo',
              value: _tipo,
              options: const [
                AppSelectOption(value: RecorrenciaTipo.semanal, label: 'Semanal'),
                AppSelectOption(value: RecorrenciaTipo.mensal, label: 'Mensal'),
                AppSelectOption(value: RecorrenciaTipo.intervalada, label: 'Intervalada'),
              ],
              onChanged: (v) => setState(() => _tipo = v!),
              validator: (v) => v == null ? 'Selecione o tipo' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_tipo == RecorrenciaTipo.semanal)
              AppSelect<int?>(
                label: 'Dia da semana',
                value: _diaSemana,
                options: [
                  for (var i = 0; i < _nomesDiaSemana.length; i++)
                    AppSelectOption(value: i, label: _nomesDiaSemana[i]),
                ],
                onChanged: (v) => setState(() => _diaSemana = v),
                validator: (v) => v == null ? 'Selecione o dia da semana' : null,
              ),
            if (_tipo == RecorrenciaTipo.mensal)
              AppTextField(
                label: 'Dia do mês (1-31)',
                controller: _diaDoMesController,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final numero = int.tryParse((v ?? '').trim());
                  if (numero == null || numero < 1 || numero > 31) return 'Informe um dia entre 1 e 31';
                  return null;
                },
              ),
            if (_tipo == RecorrenciaTipo.intervalada)
              AppTextField(
                label: 'Intervalo em dias',
                controller: _intervaloDiasController,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final numero = int.tryParse((v ?? '').trim());
                  if (numero == null || numero < 1) return 'Informe um número válido';
                  return null;
                },
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
              label: 'Professor (opcional — substitui o titular só nesta recorrência)',
              value: _professorId,
              options: [
                const AppSelectOption(value: null, label: 'Usar professor titular da turma'),
                for (final professor in _professores) AppSelectOption(value: professor.id, label: professor.nome),
              ],
              onChanged: (v) => setState(() => _professorId = v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppFormRow(children: [
              AppDateField(
                label: 'Início da vigência',
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 730)),
                value: _dataInicioVigencia,
                onChanged: (v) => setState(() => _dataInicioVigencia = v!),
                validator: (v) => v == null ? 'Informe o início da vigência' : null,
              ),
              AppDateField(
                label: 'Fim da vigência (opcional)',
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 730)),
                value: _dataFimVigencia,
                onChanged: (v) => setState(() => _dataFimVigencia = v),
              ),
            ]),
          ],
        ),
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
            onPressed: _salvando ? null : () => setState(() => _view = _AcaoRecorrenciaView.menu),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(label: 'Salvar', loading: _salvando, onPressed: _salvarEdicao),
        ],
      ),
    ];
  }
}

/// Seção "Alunos matriculados" do Detalhe da Turma — Módulo 4 (MS5).
/// `TurmaAluno` representa só a inscrição permanente do aluno na turma
/// (docs/18, seção 2 item 6): nunca cria, altera ou remove `AulaAluno`,
/// que só existe a partir do gerador de Aulas (MS6). Mesma estrutura de
/// `_RecorrenciasSection` — widget próprio isolando o carregamento/estado
/// de diálogo do `TurmaDetailScreen`.
class _AlunosMatriculadosSection extends ConsumerStatefulWidget {
  const _AlunosMatriculadosSection({required this.turmaId, required this.capacidadeMaxima});

  final String turmaId;
  final int? capacidadeMaxima;

  @override
  ConsumerState<_AlunosMatriculadosSection> createState() => _AlunosMatriculadosSectionState();
}

class _AlunosMatriculadosSectionState extends ConsumerState<_AlunosMatriculadosSection> {
  Future<List<TurmaAluno>>? _future;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _future = ref.read(turmaAlunosApiProvider).list(widget.turmaId);
    });
  }

  Future<void> _nova() async {
    final inscrito = await showAppDialog<bool>(
      context,
      maxWidth: 420,
      builder: (_) => _NovaInscricaoDialog(turmaId: widget.turmaId),
    );
    if (inscrito == true) _carregar();
  }

  Future<void> _abrirAcoes(TurmaAluno turmaAluno) async {
    final alterou = await showAppDialog<bool>(
      context,
      maxWidth: 420,
      builder: (_) => _AcoesTurmaAlunoDialog(turmaId: widget.turmaId, turmaAluno: turmaAluno),
    );
    if (alterou == true) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Alunos matriculados',
      actions: [AppButton(label: 'Nova inscrição', icon: AppIcons.add, onPressed: _nova)],
      child: FutureBuilder<List<TurmaAluno>>(
        future: _future,
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
              onAction: _carregar,
            );
          }
          final turmaAlunos = snapshot.data!;
          if (turmaAlunos.isEmpty) {
            return EmptyState(
              icon: AppIcons.enrollment,
              title: 'Nenhum aluno inscrito',
              description: 'Inscreva o primeiro aluno matriculado nesta turma.',
              actionLabel: 'Nova inscrição',
              onAction: _nova,
            );
          }
          final colors = context.colors;
          final ativos = turmaAlunos.where((t) => t.status == UserStatus.ativo).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.capacidadeMaxima != null) ...[
                Text(
                  '$ativos de ${widget.capacidadeMaxima} vagas ocupadas',
                  style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              for (var i = 0; i < turmaAlunos.length; i++) ...[
                if (i > 0) Divider(color: colors.borderSoft, height: 1),
                _TurmaAlunoRow(
                  turmaAluno: turmaAlunos[i],
                  onTap: () => _abrirAcoes(turmaAlunos[i]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TurmaAlunoRow extends StatelessWidget {
  const _TurmaAlunoRow({required this.turmaAluno, required this.onTap});

  final TurmaAluno turmaAluno;
  final VoidCallback onTap;

  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (primeira + ultima).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ativo = turmaAluno.status == UserStatus.ativo;
    final subtitle = ativo
        ? 'Desde ${dataCurtaFormat.format(turmaAluno.dataInicio)}'
        : 'Saiu em ${dataCurtaFormat.format(turmaAluno.dataFim ?? turmaAluno.dataInicio)}';

    return AppListTile(
      title: turmaAluno.alunoNome,
      subtitle: subtitle,
      leadingText: _iniciais(turmaAluno.alunoNome),
      trailing: AppBadge(
        ativo ? 'Ativo' : 'Inativo',
        tone: ativo ? AppBadgeTone.success : AppBadgeTone.neutral,
      ),
      onTap: onTap,
    );
  }
}

/// Inscrição de aluno na turma — diálogo com um único campo (`AppSelect`
/// de Aluno), mesmo padrão de seleção de entidade de `MatriculaFormScreen`/
/// `TurmaFormScreen`.
class _NovaInscricaoDialog extends ConsumerStatefulWidget {
  const _NovaInscricaoDialog({required this.turmaId});

  final String turmaId;

  @override
  ConsumerState<_NovaInscricaoDialog> createState() => _NovaInscricaoDialogState();
}

class _NovaInscricaoDialogState extends ConsumerState<_NovaInscricaoDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _alunoId;
  List<Aluno> _alunos = [];
  bool _carregandoOpcoes = true;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarOpcoes();
  }

  Future<void> _carregarOpcoes() async {
    try {
      final resultado = await ref.read(alunosApiProvider).list(status: UserStatus.ativo, pageSize: 100);
      _alunos = resultado.items;
    } on DioException catch (e) {
      _erro = mensagemErroApi(e);
    } finally {
      if (mounted) setState(() => _carregandoOpcoes = false);
    }
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await ref.read(turmaAlunosApiProvider).create(widget.turmaId, _alunoId!);
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

    return _carregandoOpcoes
        ? const SizedBox(
            height: 100,
            child: Center(child: LoadingSkeleton(width: 200, height: 16)),
          )
        : Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nova inscrição', style: AppTypography.titleLarge.copyWith(color: colors.text)),
                const SizedBox(height: AppSpacing.lg),
                AppSelect<String?>(
                  label: 'Aluno',
                  value: _alunoId,
                  options: [
                    for (final aluno in _alunos) AppSelectOption(value: aluno.id, label: aluno.nome),
                  ],
                  onChanged: (v) => setState(() => _alunoId = v),
                  validator: (v) => v == null ? 'Selecione o aluno' : null,
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
                    AppButton(label: 'Inscrever', loading: _salvando, onPressed: _salvar),
                  ],
                ),
              ],
            ),
          );
  }
}

/// Ações rápidas de uma inscrição — sair/reativar, remover. Sem "Editar":
/// `TurmaAluno` não tem nenhum campo editável além do status (docs/18,
/// seção 2 item 6) — mesmo chassi de `_AcoesModalidadeDialog`/
/// `_AcoesRecorrenciaDialog`, sem a etapa de formulário.
class _AcoesTurmaAlunoDialog extends ConsumerStatefulWidget {
  const _AcoesTurmaAlunoDialog({required this.turmaId, required this.turmaAluno});

  final String turmaId;
  final TurmaAluno turmaAluno;

  @override
  ConsumerState<_AcoesTurmaAlunoDialog> createState() => _AcoesTurmaAlunoDialogState();
}

class _AcoesTurmaAlunoDialogState extends ConsumerState<_AcoesTurmaAlunoDialog> {
  bool _salvando = false;
  String? _erro;

  Future<void> _alternarStatus() async {
    setState(() => _salvando = true);
    try {
      final novoStatus =
          widget.turmaAluno.status == UserStatus.ativo ? UserStatus.inativo : UserStatus.ativo;
      await ref.read(turmaAlunosApiProvider).updateStatus(widget.turmaId, widget.turmaAluno.id, novoStatus);
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
      title: 'Remover inscrição',
      description:
          'Remover a inscrição de ${widget.turmaAluno.alunoNome}? Use isto só para corrigir um cadastro '
          'feito por engano — para o aluno apenas sair da turma, use "Sair da turma" em vez de remover.',
      confirmLabel: 'Remover',
    );
    if (confirmou != true || !mounted) return;

    setState(() => _salvando = true);
    try {
      await ref.read(turmaAlunosApiProvider).remove(widget.turmaId, widget.turmaAluno.id);
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (mounted) setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ativo = widget.turmaAluno.status == UserStatus.ativo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.turmaAluno.alunoNome, style: AppTypography.titleLarge.copyWith(color: colors.text)),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppButton(
              label: ativo ? 'Sair da turma' : 'Reativar',
              icon: ativo ? AppIcons.block : AppIcons.circleCheck,
              variant: AppButtonVariant.secondary,
              loading: _salvando,
              onPressed: _alternarStatus,
            ),
            AppButton(
              label: 'Remover',
              icon: AppIcons.trash,
              variant: AppButtonVariant.danger,
              loading: _salvando,
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
      ],
    );
  }
}

/// Seção "Aulas" do Detalhe da Turma — Módulo 4 (MS6). Só geração +
/// leitura nesta fase: cancelamento e professor substituto são MS7
/// (Calendário), por isso as linhas aqui são só leitura, sem diálogo de
/// ações. `AppPagination` reutilizado — diferente de Recorrências/Alunos
/// matriculados, a lista de Aulas cresce sem limite (uma linha por
/// ocorrência gerada) e não cabe inteira numa tela.
class _AulasSection extends ConsumerStatefulWidget {
  const _AulasSection({required this.turmaId});

  final String turmaId;

  @override
  ConsumerState<_AulasSection> createState() => _AulasSectionState();
}

class _AulasSectionState extends ConsumerState<_AulasSection> {
  Future<PaginatedResult<Aula>>? _future;
  int _pagina = 1;
  static const _tamanhoPagina = 10;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _future = ref.read(aulasApiProvider).list(widget.turmaId, page: _pagina, pageSize: _tamanhoPagina);
    });
  }

  void _irParaPagina(int pagina) {
    setState(() => _pagina = pagina);
    _carregar();
  }

  Future<void> _gerar() async {
    final resultado = await showAppDialog<GerarAulasResultado>(
      context,
      maxWidth: 460,
      builder: (_) => _GerarAulasDialog(turmaId: widget.turmaId),
    );
    if (resultado == null) return;

    _pagina = 1;
    _carregar();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado.geradas > 0
                ? '${resultado.geradas} aula(s) geradas — ${resultado.jaExistentes} já existiam no período.'
                : 'Nenhuma aula nova — todo o período já estava gerado.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Aulas',
      actions: [AppButton(label: 'Gerar aulas', icon: AppIcons.add, onPressed: _gerar)],
      child: FutureBuilder<PaginatedResult<Aula>>(
        future: _future,
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
              title: 'Não foi possível carregar as aulas.',
              actionLabel: 'Tentar novamente',
              onAction: _carregar,
            );
          }
          final resultado = snapshot.data!;
          if (resultado.items.isEmpty) {
            return EmptyState(
              icon: AppIcons.attendance,
              title: 'Nenhuma aula gerada',
              description: 'Gere as aulas de um período a partir das recorrências desta turma.',
              actionLabel: 'Gerar aulas',
              onAction: _gerar,
            );
          }
          final colors = context.colors;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < resultado.items.length; i++) ...[
                if (i > 0) Divider(color: colors.borderSoft, height: 1),
                _AulaRow(aula: resultado.items[i]),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppPagination(
                page: resultado.page,
                pageSize: resultado.pageSize,
                total: resultado.total,
                onPageChanged: _irParaPagina,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AulaRow extends StatelessWidget {
  const _AulaRow({required this.aula});

  final Aula aula;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final agendada = aula.status == AulaStatus.agendada;

    return Padding(
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
                  '${dataCurtaFormat.format(aula.data)} · ${aula.horaInicio} (${aula.duracaoMinutos} min)',
                  style: AppTypography.titleMedium.copyWith(color: colors.text),
                ),
                Text(
                  '${aula.professorNome} · ${aula.totalAlunos} aluno(s)',
                  style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppBadge(
            agendada ? 'Agendada' : 'Cancelada',
            tone: agendada ? AppBadgeTone.success : AppBadgeTone.neutral,
          ),
        ],
      ),
    );
  }
}

/// Diálogo de geração — dois campos (`dataInicio`/`dataFim`), pré-
/// preenchidos com a janela padrão de 30 dias (docs/18, seção 7, decisão
/// confirmada). Devolve o `GerarAulasResultado` (não só `bool`) pra
/// `_AulasSection` mostrar quantas aulas foram criadas via SnackBar.
class _GerarAulasDialog extends ConsumerStatefulWidget {
  const _GerarAulasDialog({required this.turmaId});

  final String turmaId;

  @override
  ConsumerState<_GerarAulasDialog> createState() => _GerarAulasDialogState();
}

class _GerarAulasDialogState extends ConsumerState<_GerarAulasDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _dataInicio;
  late DateTime _dataFim;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _dataInicio = DateTime.now();
    _dataFim = _dataInicio.add(const Duration(days: 30));
  }

  Future<void> _gerar() async {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final resultado = await ref.read(aulasApiProvider).gerar(
            widget.turmaId,
            dataInicio: DateFormat('yyyy-MM-dd').format(_dataInicio),
            dataFim: DateFormat('yyyy-MM-dd').format(_dataFim),
          );
      if (mounted) Navigator.of(context).pop(resultado);
    } on DioException catch (e) {
      setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gerar aulas', style: AppTypography.titleLarge.copyWith(color: colors.text)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Gera as aulas de todas as recorrências ativas desta turma no período. '
            'Datas já geradas não são recriadas nem alteradas.',
            style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppFormRow(children: [
            AppDateField(
              label: 'Início do período',
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
              value: _dataInicio,
              onChanged: (v) => setState(() => _dataInicio = v!),
              validator: (v) => v == null ? 'Informe o início' : null,
            ),
            AppDateField(
              label: 'Fim do período',
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
              value: _dataFim,
              onChanged: (v) => setState(() => _dataFim = v!),
              validator: (v) => v == null ? 'Informe o fim' : null,
            ),
          ]),
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
                onPressed: _salvando ? null : () => Navigator.of(context).pop(null),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(label: 'Gerar', loading: _salvando, onPressed: _gerar),
            ],
          ),
        ],
      ),
    );
  }
}
