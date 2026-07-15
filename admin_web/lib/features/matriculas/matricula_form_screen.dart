import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

import '../../routing/back_navigation.dart';

/// Formulário de matrícula (criar/editar) — Módulo 2 (MS4), mesmo padrão
/// consolidado por `AlunoFormScreen`/`PlanoFormScreen`: seções em `AppCard`,
/// campos em `AppFormRow`, erro de campo no próprio campo,
/// `AppFormErrorBanner` pra erro de salvar.
///
/// Editar é bem mais restrito que criar: `UpdateMatriculaDto` só aceita
/// `valor`/`diaVencimento` — `alunoId`/`planoId`/`dataInicio` são imutáveis
/// depois de criada (docs/16, item 12; trocar de plano é cancelar e criar
/// de novo via `renovar`/`create`, não um campo editável aqui). Por isso em
/// modo edição esses três campos aparecem como `AppSelect`/`AppDateField`
/// **desabilitados**, preenchidos com o valor atual, em vez de sumirem —
/// mantém o layout estável e deixa claro que a informação existe mas não
/// é editável por este formulário.
///
/// Transições de status (trancar/reativar/cancelar/renovar) não entram
/// aqui — são ações de ciclo de vida, não edição de campo, e vão para o
/// Detalhe (MS5), mesmo raciocínio que já separa esses métodos de
/// `update()` na própria `MatriculasApi`.
///
/// `AppSelect` para Aluno/Plano (não um novo `AppAutocompleteField`):
/// único consumidor desse padrão até agora, e o volume de alunos/planos
/// de uma academia nesta fase do produto cabe numa lista simples — ver
/// docs/15-design-system-e-padrao-crud.md.
class MatriculaFormScreen extends ConsumerStatefulWidget {
  const MatriculaFormScreen({this.matriculaId, super.key});

  final String? matriculaId;

  @override
  ConsumerState<MatriculaFormScreen> createState() => _MatriculaFormScreenState();
}

class _MatriculaFormScreenState extends ConsumerState<MatriculaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diaVencimentoController = TextEditingController();
  final _valorController = TextEditingController();
  final _alunoNomeController = TextEditingController();
  final _planoNomeController = TextEditingController();

  String? _alunoId;
  String? _planoId;
  DateTime? _dataInicio;

  List<Aluno> _alunos = [];
  List<Plano> _planos = [];

  bool _carregando = false;
  bool _salvando = false;
  String? _erroCarregamento;
  String? _erroSalvar;

  bool get _editando => widget.matriculaId != null;

  void _cancelar() => context.backToList('/matriculas', result: false);

  @override
  void initState() {
    super.initState();
    // Pré-preenche com hoje: `AppDateField` abre o calendário em
    // `field.value ?? lastDate` — sem isso, o seletor abriria direto no
    // fim do intervalo permitido (1 ano à frente), não em "hoje".
    if (!_editando) {
      _dataInicio = DateTime.now();
      _diaVencimentoController.text = _dataInicio!.day.toString();
    }
    _carregar();
  }

  /// Carrega tudo que o formulário precisa: em modo criação, as opções de
  /// Aluno/Plano; em modo edição, a matrícula em si (aluno/plano já vêm
  /// prontos nela — `alunoNome`/`planoNome`, sem precisar das listas).
  /// Métodos separados (`_carregarOpcoes`/`_carregarMatricula`) de
  /// propósito: se um dia o seletor virar um `AppAutocompleteField` que
  /// busca sob demanda, só a camada de UI muda — o carregamento dos dados
  /// já está desacoplado do widget que os exibe.
  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erroCarregamento = null;
    });
    try {
      if (_editando) {
        await _carregarMatricula();
      } else {
        await _carregarOpcoes();
      }
    } on DioException catch (e) {
      _erroCarregamento = mensagemErroApi(e);
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _carregarOpcoes() async {
    // Duas requisições paralelas, não `Future.wait` — os tipos de retorno
    // (`PaginatedResult<Aluno>` vs. `PaginatedResult<Plano>`) são
    // diferentes, e `Future.wait` exigiria uma lista homogênea (forçando
    // um cast inseguro na leitura de `.items`).
    final alunosFuture = ref.read(alunosApiProvider).list(status: UserStatus.ativo, pageSize: 100);
    final planosFuture = ref.read(planosApiProvider).list(status: UserStatus.ativo, pageSize: 100);
    _alunos = (await alunosFuture).items;
    _planos = (await planosFuture).items;
  }

  Future<void> _carregarMatricula() async {
    final matricula = await ref.read(matriculasApiProvider).get(widget.matriculaId!);
    _alunoId = matricula.alunoId;
    _planoId = matricula.planoId;
    _dataInicio = matricula.dataInicio;
    _alunoNomeController.text = matricula.alunoNome;
    _planoNomeController.text = matricula.planoNome;
    _valorController.text = matricula.valor.toStringAsFixed(2).replaceAll('.', ',');
    _diaVencimentoController.text = matricula.diaVencimento.toString();
  }

  @override
  void dispose() {
    _diaVencimentoController.dispose();
    _valorController.dispose();
    _alunoNomeController.dispose();
    _planoNomeController.dispose();
    super.dispose();
  }

  void _aoSelecionarPlano(String? planoId) {
    setState(() => _planoId = planoId);
    // Sugere o valor do plano — só se o campo ainda não foi tocado, pra
    // não sobrescrever um desconto que o usuário já tenha digitado.
    if (planoId != null && _valorController.text.trim().isEmpty) {
      final plano = _planos.firstWhere((p) => p.id == planoId);
      _valorController.text = plano.valor.toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  void _aoSelecionarDataInicio(DateTime? data) {
    setState(() => _dataInicio = data);
    if (data != null && _diaVencimentoController.text.trim().isEmpty) {
      _diaVencimentoController.text = data.day.toString();
    }
  }

  Map<String, dynamic> _construirPayload() {
    final valor = double.parse(_valorController.text.trim().replaceAll(',', '.'));
    final diaVencimento = int.parse(_diaVencimentoController.text.trim());

    if (_editando) {
      return {'valor': valor, 'diaVencimento': diaVencimento};
    }
    return {
      'alunoId': _alunoId,
      'planoId': _planoId,
      'dataInicio': DateFormat('yyyy-MM-dd').format(_dataInicio!),
      'diaVencimento': diaVencimento,
      'valor': valor,
    };
  }

  Future<void> _salvar() async {
    setState(() => _erroSalvar = null);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _salvando = true);

    try {
      final matriculasApi = ref.read(matriculasApiProvider);
      final payload = _construirPayload();
      if (_editando) {
        await matriculasApi.update(widget.matriculaId!, payload);
      } else {
        await matriculasApi.create(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editando ? 'Matrícula atualizada com sucesso.' : 'Matrícula cadastrada com sucesso.')),
        );
        context.backToList('/matriculas', result: true);
      }
    } on DioException catch (e) {
      setState(() => _erroSalvar = mensagemErroApi(e));
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Rota fora do ShellRoute (tela cheia, sem sidebar/header) — precisa do
    // próprio Scaffold, mesma regra do AlunoFormScreen/PlanoFormScreen.
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDetailHeader(
                listLabel: 'Matrículas',
                onBack: _cancelar,
                title: _editando ? 'Editar matrícula' : 'Nova matrícula',
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_erroCarregamento != null)
                EmptyState(
                  icon: AppIcons.alert,
                  title: _erroCarregamento!,
                  actionLabel: 'Tentar novamente',
                  onAction: _carregar,
                )
              else if (_carregando)
                const _MatriculaFormSkeleton()
              else
                _formulario(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formulario(AppColorScheme colors) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            title: 'Aluno e plano',
            child: Column(
              children: [
                AppFormRow(
                  children: [
                    if (_editando)
                      AppTextField(label: 'Aluno', controller: _alunoNomeController, enabled: false)
                    else
                      AppSelect<String?>(
                        label: 'Aluno',
                        value: _alunoId,
                        options: [
                          for (final aluno in _alunos) AppSelectOption(value: aluno.id, label: aluno.nome),
                        ],
                        onChanged: (v) => setState(() => _alunoId = v),
                        validator: (v) => v == null ? 'Selecione o aluno' : null,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppFormRow(
                  children: [
                    if (_editando)
                      AppTextField(label: 'Plano', controller: _planoNomeController, enabled: false)
                    else
                      AppSelect<String?>(
                        label: 'Plano',
                        value: _planoId,
                        options: [
                          for (final plano in _planos) AppSelectOption(value: plano.id, label: plano.nome),
                        ],
                        onChanged: _aoSelecionarPlano,
                        validator: (v) => v == null ? 'Selecione o plano' : null,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            title: 'Vigência e valor',
            child: Column(
              children: [
                AppFormRow(
                  children: [
                    AppDateField(
                      label: 'Data de início',
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      value: _dataInicio,
                      enabled: !_editando,
                      onChanged: _aoSelecionarDataInicio,
                      validator: (v) => v == null ? 'Informe a data de início' : null,
                    ),
                    AppTextField(
                      label: 'Dia de vencimento',
                      hintText: '10',
                      controller: _diaVencimentoController,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final numero = int.tryParse((v ?? '').trim());
                        if (numero == null || numero < 1 || numero > 31) return 'Informe um dia entre 1 e 31';
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppFormRow(
                  children: [
                    AppTextField(
                      label: 'Valor mensal',
                      hintText: '150,00',
                      controller: _valorController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe o valor';
                        final numero = double.tryParse(v.trim().replaceAll(',', '.'));
                        if (numero == null || numero <= 0) return 'Informe um valor válido';
                        return null;
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_erroSalvar != null) ...[
            AppFormErrorBanner(_erroSalvar!),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            children: [
              AppButton(label: 'Cancelar', variant: AppButtonVariant.secondary, onPressed: _salvando ? null : _cancelar),
              const SizedBox(width: AppSpacing.sm),
              AppButton(label: 'Salvar', loading: _salvando, onPressed: _salvar),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatriculaFormSkeleton extends StatelessWidget {
  const _MatriculaFormSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(title: 'Aluno e plano', loading: true),
        SizedBox(height: AppSpacing.lg),
        AppCard(title: 'Vigência e valor', loading: true),
      ],
    );
  }
}

