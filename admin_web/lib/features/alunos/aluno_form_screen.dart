import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

/// Criação (`alunoId == null`) e edição (`alunoId != null`) de aluno — mesmo
/// formulário nos dois casos, já que os campos coincidem.
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

  bool _carregando = false;
  bool _salvando = false;
  String? _erro;

  bool get _editando => widget.alunoId != null;

  @override
  void initState() {
    super.initState();
    if (_editando) {
      _carregarAluno();
    }
  }

  Future<void> _carregarAluno() async {
    setState(() => _carregando = true);
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

  Future<void> _escolherDataNascimento() async {
    final agora = DateTime.now();
    final selecionada = await showDatePicker(
      context: context,
      initialDate: _dataNascimento ?? DateTime(agora.year - 20),
      firstDate: DateTime(1900),
      lastDate: agora,
    );
    if (selecionada != null) {
      setState(() => _dataNascimento = selecionada);
    }
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
      if (_rgController.text.trim().isNotEmpty) 'rg': _rgController.text.trim(),
      'dataNascimento': DateFormat('yyyy-MM-dd').format(_dataNascimento!),
      'sexo': _sexo!.wireValue,
      'telefone': _telefoneController.text.trim(),
      if (_whatsappController.text.trim().isNotEmpty)
        'whatsapp': _whatsappController.text.trim(),
      if (_emailController.text.trim().isNotEmpty)
        'email': _emailController.text.trim(),
      if (_enderecoController.text.trim().isNotEmpty)
        'endereco': _enderecoController.text.trim(),
      if (_cidadeController.text.trim().isNotEmpty)
        'cidade': _cidadeController.text.trim(),
      if (_estadoController.text.trim().isNotEmpty)
        'estado': _estadoController.text.trim(),
      if (_cepController.text.trim().isNotEmpty)
        'cep': _cepController.text.trim(),
      if (_observacoesController.text.trim().isNotEmpty)
        'observacoes': _observacoesController.text.trim(),
    };
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_dataNascimento == null || _sexo == null) {
      setState(() => _erro = 'Preencha data de nascimento e sexo.');
      return;
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });

    try {
      final alunosApi = ref.read(alunosApiProvider);
      final payload = _construirPayload();
      final aluno = _editando
          ? await alunosApi.update(widget.alunoId!, payload)
          : await alunosApi.create(payload);

      if (_fotoBytes != null) {
        await alunosApi.uploadFoto(
          aluno.id,
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
      appBar: AppBar(title: Text(_editando ? 'Editar aluno' : 'Novo aluno')),
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
                              controller: _rgController,
                              decoration: const InputDecoration(
                                labelText: 'RG (opcional)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _escolherDataNascimento,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Data de nascimento',
                                ),
                                child: Text(
                                  _dataNascimento != null
                                      ? DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(_dataNascimento!)
                                      : 'Selecionar',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<Sexo>(
                              initialValue: _sexo,
                              decoration: const InputDecoration(
                                labelText: 'Sexo',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: Sexo.masculino,
                                  child: Text('Masculino'),
                                ),
                                DropdownMenuItem(
                                  value: Sexo.feminino,
                                  child: Text('Feminino'),
                                ),
                                DropdownMenuItem(
                                  value: Sexo.outro,
                                  child: Text('Outro'),
                                ),
                              ],
                              onChanged: (v) => setState(() => _sexo = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _whatsappController,
                              decoration: const InputDecoration(
                                labelText: 'WhatsApp (opcional)',
                              ),
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
                        controller: _enderecoController,
                        decoration: const InputDecoration(
                          labelText: 'Endereço (opcional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cidadeController,
                              decoration: const InputDecoration(
                                labelText: 'Cidade (opcional)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _estadoController,
                              decoration: const InputDecoration(
                                labelText: 'Estado (opcional)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cepController,
                              decoration: const InputDecoration(
                                labelText: 'CEP (opcional)',
                              ),
                            ),
                          ),
                        ],
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
