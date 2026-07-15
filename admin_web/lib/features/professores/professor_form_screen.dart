import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';

import '../../routing/back_navigation.dart';

/// Formulário de professor (criar/editar) — Sprint 3, reescrita 1:1 do
/// padrão consolidado por `AlunoFormScreen` (Sprint 2, MS4): seções em
/// `AppCard`, campos em `AppFormRow`, erro de campo no próprio campo,
/// `AppFormErrorBanner` pra erro de salvar. Professor não tem data de
/// nascimento/sexo/endereço — por isso não usa `AppDateField`/`AppSelect`
/// aqui, mesmo eles fazendo parte do Design System: reuso é do padrão de
/// composição, não de "usar todo componente que existe".
class ProfessorFormScreen extends ConsumerStatefulWidget {
  const ProfessorFormScreen({this.professorId, super.key});

  final String? professorId;

  @override
  ConsumerState<ProfessorFormScreen> createState() => _ProfessorFormScreenState();
}

class _ProfessorFormScreenState extends ConsumerState<ProfessorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _especialidadeController = TextEditingController();
  final _observacoesController = TextEditingController();

  Uint8List? _fotoBytes;
  String? _fotoNomeArquivo;
  String? _fotoUrlExistente;

  bool _carregando = false;
  bool _salvando = false;
  String? _erroCarregamento;
  String? _erroSalvar;

  bool get _editando => widget.professorId != null;

  void _cancelar() => context.backToList('/professores', result: false);

  @override
  void initState() {
    super.initState();
    if (_editando) {
      _carregarProfessor();
    }
  }

  Future<void> _carregarProfessor() async {
    setState(() {
      _carregando = true;
      _erroCarregamento = null;
    });
    try {
      final professor = await ref.read(professoresApiProvider).get(widget.professorId!);
      _nomeController.text = professor.nome;
      _cpfController.text = professor.cpf;
      _telefoneController.text = professor.telefone;
      _emailController.text = professor.email ?? '';
      _especialidadeController.text = professor.especialidade ?? '';
      _observacoesController.text = professor.observacoes ?? '';
      _fotoUrlExistente = professor.fotoUrl;
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
    _telefoneController.dispose();
    _emailController.dispose();
    _especialidadeController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _construirPayload() {
    return {
      'nome': _nomeController.text.trim(),
      'cpf': _cpfController.text.trim(),
      'telefone': _telefoneController.text.trim(),
      if (_emailController.text.trim().isNotEmpty) 'email': _emailController.text.trim(),
      if (_especialidadeController.text.trim().isNotEmpty) 'especialidade': _especialidadeController.text.trim(),
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
      final professoresApi = ref.read(professoresApiProvider);
      final payload = _construirPayload();
      final professor = _editando
          ? await professoresApi.update(widget.professorId!, payload)
          : await professoresApi.create(payload);

      if (_fotoBytes != null) {
        await professoresApi.uploadFoto(professor.id, bytes: _fotoBytes!, filename: _fotoNomeArquivo!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editando ? 'Professor atualizado com sucesso.' : 'Professor cadastrado com sucesso.')),
        );
        context.backToList('/professores', result: true);
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
    // próprio Scaffold, mesma regra do AlunoFormScreen.
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDetailHeader(
                listLabel: 'Professores',
                onBack: _cancelar,
                title: _editando ? 'Editar professor' : 'Novo professor',
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_erroCarregamento != null)
                EmptyState(
                  icon: AppIcons.alert,
                  title: _erroCarregamento!,
                  actionLabel: 'Tentar novamente',
                  onAction: _carregarProfessor,
                )
              else if (_carregando)
                const _ProfessorFormSkeleton()
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
                  AppTextField(label: 'E-mail (opcional)', controller: _emailController, keyboardType: TextInputType.emailAddress),
                ]),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            title: 'Dados profissionais',
            child: AppFormRow(children: [
              AppTextField(label: 'Especialidade (opcional)', controller: _especialidadeController),
            ]),
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

class _ProfessorFormSkeleton extends StatelessWidget {
  const _ProfessorFormSkeleton();

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

