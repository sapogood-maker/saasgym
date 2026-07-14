/// Resumo de uma rodada de geração de aulas (docs/18, seção 5).
class GerarAulasResultado {
  const GerarAulasResultado({required this.geradas, required this.jaExistentes});

  factory GerarAulasResultado.fromJson(Map<String, dynamic> json) {
    return GerarAulasResultado(
      geradas: json['geradas'] as int,
      jaExistentes: json['jaExistentes'] as int,
    );
  }

  final int geradas;
  final int jaExistentes;
}
