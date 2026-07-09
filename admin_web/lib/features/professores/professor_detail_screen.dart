import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

class ProfessorDetailScreen extends ConsumerStatefulWidget {
  const ProfessorDetailScreen({required this.professorId, super.key});

  final String professorId;

  @override
  ConsumerState<ProfessorDetailScreen> createState() =>
      _ProfessorDetailScreenState();
}

class _ProfessorDetailScreenState extends ConsumerState<ProfessorDetailScreen> {
  Future<Professor>? _future;
  bool _alterado = false;
  bool _processando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _future = ref.read(professoresApiProvider).get(widget.professorId);
    });
  }

  Future<void> _alternarStatus(Professor professor) async {
    setState(() => _processando = true);
    try {
      final novoStatus = professor.status == UserStatus.ativo
          ? UserStatus.inativo
          : UserStatus.ativo;
      await ref
          .read(professoresApiProvider)
          .updateStatus(professor.id, novoStatus);
      _alterado = true;
      _carregar();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_mensagemErro(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  Future<void> _excluir(Professor professor) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover professor'),
        content: Text(
          'Remover ${professor.nome}? O cadastro fica inativo e preservado '
          '(nada é apagado permanentemente).',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmou != true) {
      return;
    }

    setState(() => _processando = true);
    try {
      await ref.read(professoresApiProvider).remove(professor.id);
      if (mounted) {
        context.pop(true);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_mensagemErro(e))));
      }
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.pop(_alterado);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Detalhe do professor')),
        body: FutureBuilder<Professor>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('Não foi possível carregar o professor.'),
              );
            }
            final professor = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: professor.fotoUrl != null
                              ? NetworkImage(professor.fotoUrl!)
                              : null,
                          child: professor.fotoUrl == null
                              ? const Icon(Icons.person, size: 32)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                professor.nome,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Chip(
                                label: Text(
                                  professor.status == UserStatus.ativo
                                      ? 'Ativo'
                                      : 'Inativo',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _linha('CPF', professor.cpf),
                    _linha('Telefone', professor.telefone),
                    _linha('E-mail', professor.email),
                    _linha('Especialidade', professor.especialidade),
                    _linha('Observações', professor.observacoes),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _processando
                              ? null
                              : () async {
                                  final resultado = await context.push<bool>(
                                    '/professores/${professor.id}/editar',
                                  );
                                  if (resultado == true) {
                                    _alterado = true;
                                    _carregar();
                                  }
                                },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _processando
                              ? null
                              : () => _alternarStatus(professor),
                          icon: Icon(
                            professor.status == UserStatus.ativo
                                ? Icons.block_outlined
                                : Icons.check_circle_outline,
                          ),
                          label: Text(
                            professor.status == UserStatus.ativo
                                ? 'Inativar'
                                : 'Reativar',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _processando
                              ? null
                              : () => _excluir(professor),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remover'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Widget _linha(String rotulo, String? valor) {
  if (valor == null || valor.isEmpty) {
    return const SizedBox.shrink();
  }
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(rotulo, style: const TextStyle(color: Colors.grey)),
        ),
        Expanded(child: Text(valor)),
      ],
    ),
  );
}

String _mensagemErro(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['message'] != null) {
    final message = data['message'];
    return message is List ? message.join(', ') : message.toString();
  }
  return 'Não foi possível concluir a operação.';
}
