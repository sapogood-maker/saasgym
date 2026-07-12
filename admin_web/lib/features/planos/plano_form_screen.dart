import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

/// Formulário de plano (criar/editar) — Módulo 1 (MS4), mesmo padrão
/// consolidado por `AlunoFormScreen`: seções em `AppCard`, campos em
/// `AppFormRow`, erro de campo no próprio campo, `AppFormErrorBanner` pra
/// erro de salvar. Sem `AppAvatarPicker` (Plano não tem foto) e sem
/// `AppDateField` (Plano não tem data).
///
/// `valor` é a primeira entrada monetária do produto — texto simples com
/// validação (aceita vírgula ou ponto como separador decimal), convertido
/// pra `double` só no payload. Deliberadamente **sem** um componente
/// `AppCurrencyField`: é a 1ª ocorrência, não a 3ª — ver
/// `docs/15-design-system-e-padrao-crud.md` para o gatilho de quando
/// reconsiderar (Financeiro, Módulo 3, é o candidato natural a confirmar
/// a repetição).
class PlanoFormScreen extends ConsumerStatefulWidget {
  const PlanoFormScreen({this.planoId, super.key});

  final String? planoId;

  @override
  ConsumerState<PlanoFormScreen> createState() => _PlanoFormScreenState();
}

class _PlanoFormScreenState extends ConsumerState<PlanoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _quantidadeAulasController = TextEditingController();
  final _ordemController = TextEditingController();

  Periodicidade? _periodicidade;

  bool _carregando = false;
  bool _salvando = false;
  String? _erroCarregamento;
  String? _erroSalvar;

  bool get _editando => widget.planoId != null;

  @override
  void initState() {
    super.initState();
    if (_editando) {
      _carregarPlano();
    }
  }

  Future<void> _carregarPlano() async {
    setState(() {
      _carregando = true;
      _erroCarregamento = null;
    });
    try {
      final plano = await ref.read(planosApiProvider).get(widget.planoId!);
      _nomeController.text = plano.nome;
      _descricaoController.text = plano.descricao ?? '';
      _valorController.text = plano.valor.toStringAsFixed(2).replaceAll('.', ',');
      _quantidadeAulasController.text = plano.quantidadeAulas?.toString() ?? '';
      _ordemController.text = plano.ordem?.toString() ?? '';
      _periodicidade = plano.periodicidade;
    } on DioException catch (e) {
      _erroCarregamento = _mensagemErro(e);
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _valorController.dispose();
    _quantidadeAulasController.dispose();
    _ordemController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _construirPayload() {
    return {
      'nome': _nomeController.text.trim(),
      if (_descricaoController.text.trim().isNotEmpty) 'descricao': _descricaoController.text.trim(),
      'periodicidade': _periodicidade!.wireValue,
      'valor': double.parse(_valorController.text.trim().replaceAll(',', '.')),
      if (_quantidadeAulasController.text.trim().isNotEmpty)
        'quantidadeAulas': int.parse(_quantidadeAulasController.text.trim()),
      if (_ordemController.text.trim().isNotEmpty) 'ordem': int.parse(_ordemController.text.trim()),
    };
  }

  Future<void> _salvar() async {
    setState(() => _erroSalvar = null);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _salvando = true);

    try {
      final planosApi = ref.read(planosApiProvider);
      final payload = _construirPayload();
      if (_editando) {
        await planosApi.update(widget.planoId!, payload);
      } else {
        await planosApi.create(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editando ? 'Plano atualizado com sucesso.' : 'Plano cadastrado com sucesso.')),
        );
        context.pop(true);
      }
    } on DioException catch (e) {
      setState(() => _erroSalvar = _mensagemErro(e));
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
    // próprio Scaffold, mesma regra do AlunoFormScreen/ProfessorFormScreen.
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editando ? 'Editar plano' : 'Novo plano',
                style: AppTypography.displayLarge.copyWith(color: colors.text),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_erroCarregamento != null)
                EmptyState(
                  icon: AppIcons.alert,
                  title: _erroCarregamento!,
                  actionLabel: 'Tentar novamente',
                  onAction: _carregarPlano,
                )
              else if (_carregando)
                const _PlanoFormSkeleton()
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
            title: 'Dados do plano',
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
                  AppSelect<Periodicidade?>(
                    label: 'Periodicidade',
                    value: _periodicidade,
                    options: const [
                      AppSelectOption(value: Periodicidade.mensal, label: 'Mensal'),
                      AppSelectOption(value: Periodicidade.trimestral, label: 'Trimestral'),
                      AppSelectOption(value: Periodicidade.semestral, label: 'Semestral'),
                      AppSelectOption(value: Periodicidade.anual, label: 'Anual'),
                    ],
                    onChanged: (v) => setState(() => _periodicidade = v),
                    validator: (v) => v == null ? 'Informe a periodicidade' : null,
                  ),
                  AppTextField(
                    label: 'Valor',
                    hintText: '129,90',
                    controller: _valorController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe o valor';
                      final numero = double.tryParse(v.trim().replaceAll(',', '.'));
                      if (numero == null || numero <= 0) return 'Informe um valor válido';
                      return null;
                    },
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
                label: 'Quantidade de aulas (opcional)',
                hintText: 'Ilimitado',
                controller: _quantidadeAulasController,
                keyboardType: TextInputType.number,
                validator: (v) => _validarInteiroOpcional(v, mensagem: 'Informe um número válido'),
              ),
              AppTextField(
                label: 'Ordem de exibição (opcional)',
                controller: _ordemController,
                keyboardType: TextInputType.number,
                validator: (v) => _validarInteiroOpcional(v, mensagem: 'Informe um número válido'),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            title: 'Observações',
            child: AppTextField(label: 'Observações (opcional)', controller: _descricaoController, maxLines: 3),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_erroSalvar != null) ...[
            AppFormErrorBanner(_erroSalvar!),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            children: [
              AppButton(label: 'Cancelar', variant: AppButtonVariant.secondary, onPressed: _salvando ? null : () => context.pop(false)),
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

class _PlanoFormSkeleton extends StatelessWidget {
  const _PlanoFormSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(title: 'Dados do plano', loading: true),
        SizedBox(height: AppSpacing.lg),
        AppCard(title: 'Detalhes', loading: true),
      ],
    );
  }
}

String _mensagemErro(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['message'] != null) {
    final message = data['message'];
    return message is List ? message.join(', ') : message.toString();
  }
  return 'Não foi possível concluir a operação.';
}
