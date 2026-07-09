import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

/// Criação (`professorId == null`) e edição (`professorId != null`) de
/// professor — mesmo formulário nos dois casos.
class ProfessorFormScreen extends ConsumerStatefulWidget {
  const ProfessorFormScreen({this.professorId, super.key});

  final String? professorId;

  @override
  ConsumerState<ProfessorFormScreen> createState() =>
      _ProfessorFormScreenState();
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

  bool _carregando = false;
  bool _salvando = false;
  String? _erro;

  bool get _editando => widget.professorId != null;

  @override
  void initState() {
    super.initState();
    if (_editando) {
      _carregarProfessor();
    }
  }

  Future<void> _carregarProfessor() async {
    setState(() => _carregando = true);
    try {
      final professor = await ref
          .read(professoresApiProvider)
          .get(widget.professorId!);
      _nomeController.text = professor.nome;
      _cpfController.text = professor.cpf;
      _telefoneController.text = professor.telefone;
      _emailController.text = professor.email ?? '';
      _especialidadeController.text = professor.especialidade ?? '';
      _observacoesController.text = professor.observacoes ?? '';
    } on DioException catch (e) {
      _erro = _mensagemErro(e);
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

  Future<void> _escolherFoto() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final arquivos = resultado?.files ?? const [];
    if (arquivos.isEmpty || arquivos.first.bytes == null) {
      return;
    }
    setState(() {
      _fotoBytes = arquivos.first.bytes;
      _fotoNomeArquivo = arquivos.first.name;
    });
  }

  Map<String, dynamic> _construirPayload() {
    return {
      'nome': _nomeController.text.trim(),
      'cpf': _cpfController.text.trim(),
      'telefone': _telefoneController.text.trim(),
      if (_emailController.text.trim().isNotEmpty)
        'email': _emailController.text.trim(),
      if (_especialidadeController.text.trim().isNotEmpty)
        'especialidade': _especialidadeController.text.trim(),
      if (_observacoesController.text.trim().isNotEmpty)
        'observacoes': _observacoesController.text.trim(),
    };
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });

    try {
      final professoresApi = ref.read(professoresApiProvider);
      final payload = _construirPayload();
      final professor = _editando
          ? await professoresApi.update(widget.professorId!, payload)
          : await professoresApi.create(payload);

      if (_fotoBytes != null) {
        await professoresApi.uploadFoto(
          professor.id,
          bytes: _fotoBytes!,
          filename: _fotoNomeArquivo!,
        );
      }

      if (mounted) {
        context.pop(true);
      }
    } on DioException catch (e) {
      setState(() => _erro = _mensagemErro(e));
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar professor' : 'Novo professor'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundImage: _fotoBytes != null
                                  ? MemoryImage(_fotoBytes!)
                                  : null,
                              child: _fotoBytes == null
                                  ? const Icon(Icons.person, size: 40)
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: IconButton.filled(
                                icon: const Icon(Icons.camera_alt, size: 18),
                                onPressed: _escolherFoto,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(labelText: 'Nome'),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Informe o nome'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cpfController,
                              decoration: const InputDecoration(
                                labelText: 'CPF',
                                hintText: '000.000.000-00',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Informe o CPF'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _telefoneController,
                              decoration: const InputDecoration(
                                labelText: 'Telefone',
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().length < 8)
                                  ? 'Informe o telefone'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'E-mail (opcional)',
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _especialidadeController,
                        decoration: const InputDecoration(
                          labelText: 'Especialidade (opcional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _observacoesController,
                        decoration: const InputDecoration(
                          labelText: 'Observações (opcional)',
                        ),
                        maxLines: 3,
                      ),
                      if (_erro != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _erro!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _salvando ? null : _salvar,
                        child: _salvando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Salvar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
