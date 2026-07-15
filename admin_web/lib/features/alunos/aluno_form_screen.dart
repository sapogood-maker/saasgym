import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

import '../../routing/back_navigation.dart';

/// Formulário de aluno (criar/editar) — referência de composição para todo
/// formulário futuro do sistema (Professores, Planos, Turmas, Academias):
/// seções em `AppCard` (Dados pessoais/Contato/Endereço/Observações/Ações),
/// campos em `AppFormRow` (2 colunas no desktop, 1 no mobile), erro de
/// campo no próprio campo (chassi do MS1), erro de salvar num
/// `AppFormErrorBanner` — nunca `SnackBar` pra nenhum dos dois.
class AlunoFormScreen extends ConsumerStatefulWidget {
  const AlunoFormScreen({this.alunoId, super.key});

  final String? alunoId;

  @override
  ConsumerState<AlunoFormScreen> createState() => _AlunoFormScreenState();
}

class _AlunoFormScreenState extends ConsumerState<AlunoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _rgController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _estadoController = TextEditingController();
  final _cepController = TextEditingController();
  final _observacoesController = TextEditingController();

  DateTime? _dataNascimento;
  Sexo? _sexo;
  Uint8List? _fotoBytes;
  String? _fotoNomeArquivo;
  String? _fotoUrlExistente;

  bool _carregando = false;
  bool _salvando = false;
  String? _erroCarregamento;
  String? _erroSalvar;

  bool get _editando => widget.alunoId != null;

  void _cancelar() => context.backToList('/alunos', result: false);

  @override
  void initState() {
    super.initState();
    if (_editando) {
      _carregarAluno();
    }
  }

  Future<void> _carregarAluno() async {
    setState(() {
      _carregando = true;
      _erroCarregamento = null;
    });
    try {
      final aluno = await ref.read(alunosApiProvider).get(widget.alunoId!);
      _nomeController.text = aluno.nome;
      _cpfController.text = aluno.cpf;
      _rgController.text = aluno.rg ?? '';
      _telefoneController.text = aluno.telefone;
      _whatsappController.text = aluno.whatsapp ?? '';
      _emailController.text = aluno.email ?? '';
      _enderecoController.text = aluno.endereco ?? '';
      _cidadeController.text = aluno.cidade ?? '';
      _estadoController.text = aluno.estado ?? '';
      _cepController.text = aluno.cep ?? '';
      _observacoesController.text = aluno.observacoes ?? '';
      _dataNascimento = aluno.dataNascimento;
      _sexo = aluno.sexo;
      _fotoUrlExistente = aluno.fotoUrl;
    } on DioException catch (e) {
      _erroCarregamento = mensagemErroApi(e);
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cpfController.dispose();
    _rgController.dispose();
    _telefoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _enderecoController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    _cepController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _construirPayload() {
    return {
      'nome': _nomeController.text.trim(),
      'cpf': _cpfController.text.trim(),
      if (_rgController.text.trim().isNotEmpty) 'rg': _rgController.text.trim(),
      'dataNascimento': DateFormat('yyyy-MM-dd').format(_dataNascimento!),
      'sexo': _sexo!.wireValue,
      'telefone': _telefoneController.text.trim(),
      if (_whatsappController.text.trim().isNotEmpty) 'whatsapp': _whatsappController.text.trim(),
      if (_emailController.text.trim().isNotEmpty) 'email': _emailController.text.trim(),
      if (_enderecoController.text.trim().isNotEmpty) 'endereco': _enderecoController.text.trim(),
      if (_cidadeController.text.trim().isNotEmpty) 'cidade': _cidadeController.text.trim(),
      if (_estadoController.text.trim().isNotEmpty) 'estado': _estadoController.text.trim(),
      if (_cepController.text.trim().isNotEmpty) 'cep': _cepController.text.trim(),
      if (_observacoesController.text.trim().isNotEmpty) 'observacoes': _observacoesController.text.trim(),
    };
  }

  Future<void> _salvar() async {
    setState(() => _erroSalvar = null);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _salvando = true);

    try {
      final alunosApi = ref.read(alunosApiProvider);
      final payload = _construirPayload();
      final aluno = _editando
          ? await alunosApi.update(widget.alunoId!, payload)
          : await alunosApi.create(payload);

      if (_fotoBytes != null) {
        await alunosApi.uploadFoto(aluno.id, bytes: _fotoBytes!, filename: _fotoNomeArquivo!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editando ? 'Aluno atualizado com sucesso.' : 'Aluno cadastrado com sucesso.')),
        );
        context.backToList('/alunos', result: true);
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
    // próprio Scaffold, diferente de telas como Dashboard/Alunos que vivem
    // dentro do AppShell e herdam o Scaffold dele.
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDetailHeader(
                listLabel: 'Alunos',
                onBack: _cancelar,
                title: _editando ? 'Editar aluno' : 'Novo aluno',
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_erroCarregamento != null)
                EmptyState(
                  icon: AppIcons.alert,
                  title: _erroCarregamento!,
                  actionLabel: 'Tentar novamente',
                  onAction: _carregarAluno,
                )
              else if (_carregando)
                const _AlunoFormSkeleton()
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
          Center(
            child: AppAvatarPicker(
              imageBytes: _fotoBytes,
              imageUrl: _fotoUrlExistente,
              radius: 48,
              onPicked: (pick) => setState(() {
                _fotoBytes = pick.bytes;
                _fotoNomeArquivo = pick.filename;
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            title: 'Dados pessoais',
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
                  AppTextField(
                    label: 'CPF',
                    hintText: '000.000.000-00',
                    controller: _cpfController,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o CPF' : null,
                  ),
                  AppTextField(label: 'RG (opcional)', controller: _rgController),
                ]),
                const SizedBox(height: AppSpacing.md),
                AppFormRow(children: [
                  AppDateField(
                    label: 'Data de nascimento',
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                    value: _dataNascimento,
                    onChanged: (v) => setState(() => _dataNascimento = v),
                    validator: (v) => v == null ? 'Informe a data de nascimento' : null,
                  ),
                  AppSelect<Sexo?>(
                    label: 'Sexo',
                    value: _sexo,
                    options: const [
                      AppSelectOption(value: Sexo.masculino, label: 'Masculino'),
                      AppSelectOption(value: Sexo.feminino, label: 'Feminino'),
                      AppSelectOption(value: Sexo.outro, label: 'Outro'),
                    ],
                    onChanged: (v) => setState(() => _sexo = v),
                    validator: (v) => v == null ? 'Informe o sexo' : null,
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            title: 'Contato',
            child: Column(
              children: [
                AppFormRow(children: [
                  AppTextField(
                    label: 'Telefone',
                    controller: _telefoneController,
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().length < 8) ? 'Informe o telefone' : null,
                  ),
                  AppTextField(label: 'WhatsApp (opcional)', controller: _whatsappController, keyboardType: TextInputType.phone),
                ]),
                const SizedBox(height: AppSpacing.md),
                AppFormRow(children: [
                  AppTextField(label: 'E-mail (opcional)', controller: _emailController, keyboardType: TextInputType.emailAddress),
                ]),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            title: 'Endereço',
            child: Column(
              children: [
                AppFormRow(children: [
                  AppTextField(label: 'Endereço (opcional)', controller: _enderecoController),
                ]),
                const SizedBox(height: AppSpacing.md),
                AppFormRow(children: [
                  AppTextField(label: 'Cidade (opcional)', controller: _cidadeController),
                  AppTextField(label: 'Estado (opcional)', controller: _estadoController),
                  AppTextField(label: 'CEP (opcional)', controller: _cepController),
                ]),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            title: 'Observações',
            child: AppTextField(label: 'Observações (opcional)', controller: _observacoesController, maxLines: 3),
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

class _AlunoFormSkeleton extends StatelessWidget {
  const _AlunoFormSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LoadingSkeleton(width: 96, height: 96, shape: AppSkeletonShape.circle),
        SizedBox(height: AppSpacing.xl),
        AppCard(title: 'Dados pessoais', loading: true),
        SizedBox(height: AppSpacing.lg),
        AppCard(title: 'Contato', loading: true),
      ],
    );
  }
}

