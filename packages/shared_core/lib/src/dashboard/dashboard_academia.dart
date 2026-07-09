/// Aniversariante do mês corrente — parte do dashboard da academia.
class Aniversariante {
  const Aniversariante({
    required this.id,
    required this.nome,
    required this.dataNascimento,
  });

  factory Aniversariante.fromJson(Map<String, dynamic> json) {
    return Aniversariante(
      id: json['id'] as String,
      nome: json['nome'] as String,
      dataNascimento: DateTime.parse(json['dataNascimento'] as String),
    );
  }

  final String id;
  final String nome;
  final DateTime dataNascimento;
}

/// Visão geral da própria academia — `GET /dashboard`. Ainda sem
/// Agenda/Financeiro (chegam em sprints futuros).
class DashboardAcademia {
  const DashboardAcademia({
    required this.totalAlunos,
    required this.alunosAtivos,
    required this.totalProfessores,
    required this.novosAlunosMes,
    required this.aniversariantes,
    required this.usuariosDoSistema,
  });

  factory DashboardAcademia.fromJson(Map<String, dynamic> json) {
    return DashboardAcademia(
      totalAlunos: json['totalAlunos'] as int,
      alunosAtivos: json['alunosAtivos'] as int,
      totalProfessores: json['totalProfessores'] as int,
      novosAlunosMes: json['novosAlunosMes'] as int,
      aniversariantes: (json['aniversariantes'] as List)
          .cast<Map<String, dynamic>>()
          .map(Aniversariante.fromJson)
          .toList(),
      usuariosDoSistema: json['usuariosDoSistema'] as int,
    );
  }

  final int totalAlunos;
  final int alunosAtivos;
  final int totalProfessores;
  final int novosAlunosMes;
  final List<Aniversariante> aniversariantes;
  final int usuariosDoSistema;
}
