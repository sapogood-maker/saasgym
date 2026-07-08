import 'package:flutter/material.dart';

/// Placeholder do Sprint 0. O fluxo real de login (POST /auth/login, refresh
/// token via cookie httpOnly) chega no Sprint 1, junto com o módulo `auth`
/// do backend e o restante do portal do aluno no Sprint 9.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SaaSGym — Portal do Aluno')),
      body: const Center(child: Text('Setup inicial concluído.')),
    );
  }
}
