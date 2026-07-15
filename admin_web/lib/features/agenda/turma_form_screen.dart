import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';

import '../../routing/back_navigation.dart';

/// Formulário de turma (criar/editar) — Módulo 4 (MS3), mesmo padrão
/// consolidado por `PlanoFormScreen`/`MatriculaFormScreen`: seções em
/// `AppCard`, campos em `AppFormRow`, `AppFormErrorBanner` pra erro de
/// salvar.
///
/// Diferença deliberada do padrão de `MatriculaFormScreen`: lá,
/// `alunoId`/`planoId` viram `AppTextField` desabilitado em modo edição
/// (imutáveis depois de criada). Aqui `modalidadeId`/`professorId`
/// continuam `AppSelect` **editáveis** também em edição — `UpdateTurmaDto`
/// aceita as duas trocas (docs/18, "O papel de Turma no domínio": Turma é
/// só o agrupamento lógico, então reatribuir modalidade/professor titular
/// não quebra nenhuma invariante de aula/recorrência já gerada).
class TurmaFormScreen extends ConsumerStatefulWidget {
  const TurmaFormScreen({this.turmaId, super.key});

  final String? turmaId;

  @override
  ConsumerState<TurmaFormScreen> createState() => _TurmaFormScreenState();
}

class _TurmaFormScreenState extends ConsumerState<TurmaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _capacidadeMaximaController = TextEditingController();
  final _localController = TextEditingController();

  String? _modalidadeId;
  String? _professorId;

  List<Modalidade> _modalidades = [];
  List<Professor> _professores = [];

  bool _carregando = false;
  bool _salvando = false;
  String? _erroCarregamento;
  String? _erroSalvar;

  bool get _editando => widget.turmaId != null;

  void _cancelar() => context.backToList('/agenda/turmas', result: false);

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erroCarregamento = null;
    });
    try {
      await _carregarOpcoes();
      if (_editando) {
        await _carregarTurma();
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
    final modalidadesFuture = ref.read(modalidadesApiProvider).list(status: UserStatus.ativo, pageSize: 100);
    final professoresFuture = ref.read(professoresApiProvider).list(status: UserStatus.ativo, pageSize: 100);
    _modalidades = (await modalidadesFuture).items;
    _professores = (await professoresFuture).items;
  }

  Future<void> _carregarTurma() async {
    final turma = await ref.read(turmasApiProvider).get(widget.turmaId!);
    _nomeController.text = turma.nome;
    _capacidadeMaximaController.text = turma.capacidadeMaxima?.toString() ?? '';
    _localController.text = turma.local ?? '';
    _modalidadeId = turma.modalidadeId;
    _professorId = turma.professorId;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _capacidadeMaximaController.dispose();
    _localController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _construirPayload() {
    return {
      'nome': _nomeController.text.trim(),
      'modalidadeId': _modalidadeId,
      'professorId': _professorId,
      if (_capacidadeMaximaController.text.trim().isNotEmpty)
        'capacidadeMaxima': int.parse(_capacidadeMaximaController.text.trim()),
      if (_localController.text.trim().isNotEmpty) 'local': _localController.text.trim(),
    };
  }

  Future<void> _salvar() async {
    setState(() => _erroSalvar = null);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _salvando = true);

    try {
      final turmasApi = ref.read(turmasApiProvider);
      final payload = _construirPayload();
      if (_editando) {
        await turmasApi.update(widget.turmaId!, payload);
      } else {
        await turmasApi.create(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editando ? 'Turma atualizada com sucesso.' : 'Turma cadastrada com sucesso.')),
        );
        context.backToList('/agenda/turmas', result: true);
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
    // próprio Scaffold, mesma regra do PlanoFormScreen/MatriculaFormScreen.
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDetailHeader(
                listLabel: 'Turmas',
                onBack: _cancelar,
                title: _editando ? 'Editar turma' : 'Nova turma',
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
                const _TurmaFormSkeleton()
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
            title: 'Dados da turma',
            child: Column(
              children: [
                AppFormRow(children: [
                  AppTextField(
                    label: 'Nome',
                    controller: _nomeController,
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Informe o nome' : null,
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                AppFormRow(children: [
                  AppSelect<String?>(
                    label: 'Modalidade',
                    value: _modalidadeId,
                    options: [
                      for (final modalidade in _modalidades)
                        AppSelectOption(value: modalidade.id, label: modalidade.nome),
                    ],
                    onChanged: (v) => setState(() => _modalidadeId = v),
                    validator: (v) => v == null ? 'Selecione a modalidade' : null,
                  ),
                  AppSelect<String?>(
                    label: 'Professor titular',
                    value: _professorId,
                    options: [
                      for (final professor in _professores)
                        AppSelectOption(value: professor.id, label: professor.nome),
                    ],
                    onChanged: (v) => setState(() => _professorId = v),
                    validator: (v) => v == null ? 'Selecione o professor' : null,
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            title: 'Detalhes',
            child: AppFormRow(children: [
              AppTextField(
                label: 'Capacidade máxima (opcional)',
                hintText: 'Ilimitado',
                controller: _capacidadeMaximaController,
                keyboardType: TextInputType.number,
                validator: (v) => _validarInteiroOpcional(v, mensagem: 'Informe um número válido'),
              ),
              AppTextField(label: 'Local (opcional)', controller: _localController),
            ]),
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

String? _validarInteiroOpcional(String? v, {required String mensagem}) {
  if (v == null || v.trim().isEmpty) return null;
  final numero = int.tryParse(v.trim());
  if (numero == null || numero <= 0) return mensagem;
  return null;
}

class _TurmaFormSkeleton extends StatelessWidget {
  const _TurmaFormSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(title: 'Dados da turma', loading: true),
        SizedBox(height: AppSpacing.lg),
        AppCard(title: 'Detalhes', loading: true),
      ],
    );
  }
}

