import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

/// Janela de "matrícula vencendo em breve" usada só pra agrupamento visual
/// do Dashboard — não é uma regra de negócio (não altera nada em
/// MatriculasService), é só o recorte que a recepção enxerga aqui.
const diasJanelaVencimentoMatricula = 15;

final _formatoIso = DateFormat('yyyy-MM-dd');

DateTime _hojeUtc() {
  final agora = DateTime.now().toUtc();
  return DateTime.utc(agora.year, agora.month, agora.day);
}

/// Dados complementares do Dashboard — nenhum vem do `GET /dashboard`
/// (Sprint de redesenho, docs/32): cada campo é resultado de reaproveitar
/// endpoints de listagem já existentes (nunca uma rota nova), lendo `.total`
/// quando o filtro do backend já dá o número exato, ou contando localmente
/// quando só existe filtro por mês inteiro (não há filtro por dia na API de
/// Mensalidades) — nesse caso o cálculo fica limitado ao que cabe em uma
/// página de até 100 itens (o teto de paginação do backend), suficiente pra
/// uma academia até esse porte; documentado aqui, não escondido.
class DashboardExtras {
  const DashboardExtras({
    required this.matriculasAtivas,
    required this.mensalidadesVenceEsteMes,
    required this.mensalidadesVenceHoje,
    required this.mensalidadesVenceEstaSemana,
    required this.novasMatriculasMes,
    required this.novasMatriculasMesAnterior,
    required this.cancelamentosMes,
    required this.cancelamentosMesAnterior,
    required this.aulasRealizadasMes,
    required this.aulasRealizadasMesAnterior,
    required this.reposicoesPendentes,
    required this.matriculasVencendoEmBreve,
    required this.notificacoesNaoLidas,
  });

  final int matriculasAtivas;

  final int mensalidadesVenceEsteMes;
  final int mensalidadesVenceHoje;
  final int mensalidadesVenceEstaSemana;

  final int novasMatriculasMes;
  final int? novasMatriculasMesAnterior;
  final int cancelamentosMes;
  final int? cancelamentosMesAnterior;

  final int aulasRealizadasMes;
  final int? aulasRealizadasMesAnterior;

  final int reposicoesPendentes;
  final int matriculasVencendoEmBreve;
  final int notificacoesNaoLidas;
}

/// Quantas mensalidades `pendentes` têm `dataVencimento` em
/// `[inicio, fimExclusivo)` — mesmo critério de intervalo meio-aberto usado
/// no backend (`intervaloDoMes`).
int contarMensalidadesNoIntervalo(
  List<Mensalidade> pendentes,
  DateTime inicio,
  DateTime fimExclusivo,
) {
  return pendentes
      .where(
        (m) =>
            !m.dataVencimento.isBefore(inicio) && m.dataVencimento.isBefore(fimExclusivo),
      )
      .length;
}

/// "Realizada" nunca é um status armazenado (mesmo princípio de
/// `Mensalidade.atrasada`) — é `AGENDADA` (não cancelada) com `data` antes
/// de hoje.
int contarAulasRealizadas(List<Aula> aulas, DateTime hoje) {
  return aulas
      .where((a) => a.status == AulaStatus.agendada && a.data.isBefore(hoje))
      .length;
}

/// Matrículas ATIVA cujo `dataFimPrevista` cai nos próximos [janelaDias]
/// dias (hoje incluso) — usa só o que já veio na página buscada (até 100
/// itens, teto do backend).
int contarMatriculasVencendo(
  List<Matricula> ativas,
  DateTime hoje, {
  int janelaDias = diasJanelaVencimentoMatricula,
}) {
  final limite = hoje.add(Duration(days: janelaDias));
  return ativas
      .where(
        (m) => !m.dataFimPrevista.isBefore(hoje) && m.dataFimPrevista.isBefore(limite),
      )
      .length;
}

final dashboardExtrasProvider = FutureProvider.autoDispose<DashboardExtras>((ref) async {
  final matriculasApi = ref.watch(matriculasApiProvider);
  final mensalidadesApi = ref.watch(mensalidadesApiProvider);
  final relatoriosApi = ref.watch(relatoriosApiProvider);
  final aulasApi = ref.watch(aulasApiProvider);
  final reposicoesApi = ref.watch(solicitacoesReposicaoApiProvider);
  final notificacoesApi = ref.watch(notificacoesApiProvider);

  final hoje = _hojeUtc();
  final inicioMes = DateTime.utc(hoje.year, hoje.month, 1);
  final inicioProximoMes = DateTime.utc(hoje.year, hoje.month + 1, 1);
  final fimSemana = hoje.add(const Duration(days: 7));

  final mesAnteriorRef = DateTime.utc(hoje.year, hoje.month - 1, 1);
  final inicioMesAnterior = mesAnteriorRef;
  final inicioMesAtualParaAnterior = DateTime.utc(hoje.year, hoje.month, 1);

  // Uma chamada só de matrículas ATIVA (pageSize 100, o teto do backend):
  // `.total` já vem exato nela (é uma query de COUNT à parte, independente
  // da paginação) — pedir de novo com pageSize:1 só pro total seria uma
  // segunda chamada idêntica, sem necessidade.
  final resultados = await Future.wait([
    mensalidadesApi.listMensalidades(
      status: MensalidadeStatus.pendente,
      mes: hoje.month,
      ano: hoje.year,
      page: 1,
      pageSize: 100,
    ),
    relatoriosApi.alunos(meses: 2),
    aulasApi.listCalendario(
      dataInicio: _formatoIso.format(inicioMes),
      dataFim: _formatoIso.format(inicioProximoMes),
      pageSize: 200,
    ),
    aulasApi.listCalendario(
      dataInicio: _formatoIso.format(inicioMesAnterior),
      dataFim: _formatoIso.format(inicioMesAtualParaAnterior),
      pageSize: 200,
    ),
    reposicoesApi.list(status: SolicitacaoReposicaoStatus.pendente, page: 1, pageSize: 1),
    matriculasApi.listMatriculas(status: MatriculaStatus.ativa, page: 1, pageSize: 100),
    notificacoesApi.list(pageSize: 1),
  ]);

  final mensalidadesMesResult = resultados[0] as PaginatedResult<Mensalidade>;
  final relatorioAlunos = resultados[1] as List<RelatorioAlunosMensalItem>;
  final aulasMesAtual = resultados[2] as PaginatedResult<Aula>;
  final aulasMesAnterior = resultados[3] as PaginatedResult<Aula>;
  final reposicoesResult = resultados[4] as PaginatedResult<SolicitacaoReposicao>;
  final matriculasAtivasCompletas = resultados[5] as PaginatedResult<Matricula>;
  final notificacoesResult = resultados[6] as NotificacoesPaginadas;

  final mesAtualRelatorio = relatorioAlunos.isNotEmpty ? relatorioAlunos[0] : null;
  final mesAnteriorRelatorio = relatorioAlunos.length > 1 ? relatorioAlunos[1] : null;

  return DashboardExtras(
    matriculasAtivas: matriculasAtivasCompletas.total,
    mensalidadesVenceEsteMes: mensalidadesMesResult.total,
    mensalidadesVenceHoje: contarMensalidadesNoIntervalo(
      mensalidadesMesResult.items,
      hoje,
      hoje.add(const Duration(days: 1)),
    ),
    mensalidadesVenceEstaSemana: contarMensalidadesNoIntervalo(
      mensalidadesMesResult.items,
      hoje,
      fimSemana,
    ),
    novasMatriculasMes: mesAtualRelatorio?.novosAlunos ?? 0,
    novasMatriculasMesAnterior: mesAnteriorRelatorio?.novosAlunos,
    cancelamentosMes: mesAtualRelatorio?.cancelamentos ?? 0,
    cancelamentosMesAnterior: mesAnteriorRelatorio?.cancelamentos,
    aulasRealizadasMes: contarAulasRealizadas(aulasMesAtual.items, hoje),
    aulasRealizadasMesAnterior: contarAulasRealizadas(aulasMesAnterior.items, inicioMes),
    reposicoesPendentes: reposicoesResult.total,
    matriculasVencendoEmBreve: contarMatriculasVencendo(matriculasAtivasCompletas.items, hoje),
    notificacoesNaoLidas: notificacoesResult.naoLidas,
  );
});
