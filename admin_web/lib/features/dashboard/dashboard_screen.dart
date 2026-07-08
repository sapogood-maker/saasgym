import 'package:flutter/material.dart';

/// Placeholder do Sprint 0. O dashboard real (alunos ativos, agenda do dia,
/// faturamento, mensalidades vencidas/próximas) chega no Sprint 7, quando os
/// módulos que alimentam esses indicadores já existirem.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SaaSGym — Painel Administrativo')),
      body: const Center(child: Text('Setup inicial concluído.')),
    );
  }
}
