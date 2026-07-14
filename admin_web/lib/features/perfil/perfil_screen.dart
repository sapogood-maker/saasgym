import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

final _perfilProvider = FutureProvider.autoDispose<UserProfile>((ref) {
  return ref.watch(usersApiProvider).me();
});

class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(_perfilProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: perfilAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (erro, _) =>
            Center(child: Text('Erro ao carregar perfil: $erro')),
        data: (perfil) => _PerfilConteudo(perfil: perfil),
      ),
    );
  }
}

class _PerfilConteudo extends ConsumerStatefulWidget {
  const _PerfilConteudo({required this.perfil});

  final UserProfile perfil;

  @override
  ConsumerState<_PerfilConteudo> createState() => _PerfilConteudoState();
}

class _PerfilConteudoState extends ConsumerState<_PerfilConteudo> {
  late final _nomeController = TextEditingController(text: widget.perfil.nome);
  final _nomeFormKey = GlobalKey<FormState>();
  bool _salvandoNome = false;
  bool _enviandoFoto = false;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _salvarNome() async {
    if (!_nomeFormKey.currentState!.validate()) {
      return;
    }
    setState(() => _salvandoNome = true);
    try {
      await ref
          .read(usersApiProvider)
          .updateMe(nome: _nomeController.text.trim());
      ref.invalidate(_perfilProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nome atualizado.')));
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemErroApi(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _salvandoNome = false);
      }
    }
  }

  Future<void> _trocarFoto() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final arquivos = resultado?.files ?? const [];
    if (arquivos.isEmpty || arquivos.first.bytes == null) {
      return;
    }
    final arquivo = arquivos.first;

    setState(() => _enviandoFoto = true);
    try {
      await ref
          .read(usersApiProvider)
          .uploadFoto(bytes: arquivo.bytes!, filename: arquivo.name);
      ref.invalidate(_perfilProvider);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemErroApi(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _enviandoFoto = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = widget.perfil;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: perfil.fotoUrl != null
                        ? NetworkImage(perfil.fotoUrl!)
                        : null,
                    child: perfil.fotoUrl == null
                        ? Text(
                            perfil.nome.isNotEmpty
                                ? perfil.nome[0].toUpperCase()
                                : '?',
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      icon: _enviandoFoto
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt, size: 18),
                      onPressed: _enviandoFoto ? null : _trocarFoto,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text(perfil.email)),
            Center(
              child: Text(
                perfil.role.wireValue,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Dados pessoais',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Form(
              key: _nomeFormKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(labelText: 'Nome'),
                      validator: (value) =>
                          (value == null || value.trim().length < 2)
                          ? 'Informe um nome válido'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _salvandoNome ? null : _salvarNome,
                    child: _salvandoNome
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salvar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const _TrocarSenhaForm(),
          ],
        ),
      ),
    );
  }
}


class _TrocarSenhaForm extends ConsumerStatefulWidget {
  const _TrocarSenhaForm();

  @override
  ConsumerState<_TrocarSenhaForm> createState() => _TrocarSenhaFormState();
}

class _TrocarSenhaFormState extends ConsumerState<_TrocarSenhaForm> {
  final _formKey = GlobalKey<FormState>();
  final _senhaAtualController = TextEditingController();
  final _senhaNovaController = TextEditingController();
  final _senhaConfirmacaoController = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _senhaAtualController.dispose();
    _senhaNovaController.dispose();
    _senhaConfirmacaoController.dispose();
    super.dispose();
  }

  Future<void> _trocarSenha() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await ref
          .read(authApiProvider)
          .changePassword(
            currentPassword: _senhaAtualController.text,
            newPassword: _senhaNovaController.text,
          );
      // O backend revoga todas as sessões (limpa o cookie de refresh) ao
      // trocar a senha — a sessão local também precisa ser encerrada.
      ref.read(authSessionProvider.notifier).clear();
      if (mounted) {
        context.go('/login');
      }
    } on DioException catch (e) {
      setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Trocar senha', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _senhaAtualController,
            decoration: const InputDecoration(labelText: 'Senha atual'),
            obscureText: true,
            validator: (value) => (value == null || value.isEmpty)
                ? 'Informe a senha atual'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _senhaNovaController,
            decoration: const InputDecoration(
              labelText: 'Nova senha',
              helperText:
                  'Mínimo 8 caracteres, com maiúscula, minúscula e número',
            ),
            obscureText: true,
            validator: (value) => (value == null || value.length < 8)
                ? 'Senha muito curta'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _senhaConfirmacaoController,
            decoration: const InputDecoration(
              labelText: 'Confirmar nova senha',
            ),
            obscureText: true,
            validator: (value) => value != _senhaNovaController.text
                ? 'As senhas não coincidem'
                : null,
          ),
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(
              _erro!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _salvando ? null : _trocarSenha,
            child: _salvando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Trocar senha'),
          ),
        ],
      ),
    );
  }
}
