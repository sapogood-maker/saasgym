import {
  MatriculaStatus,
  MotivoCancelamento,
  Prisma,
  SolicitacaoReposicaoStatus,
  UserStatus,
} from '@prisma/client';

export interface ResumoEncerramentoVinculo {
  matriculasCanceladas: number;
  turmaAlunosDesativados: number;
  aulasFuturasRemovidas: number;
  solicitacoesReposicaoRejeitadas: number;
}

/// Ponto único da regra "arquivar/remover um Aluno encerra o vínculo dele
/// com a academia" (docs/32 — auditoria de ciclo de vida do Aluno).
/// Chamada de dentro da mesma transação que `AlunosService.updateStatus()`
/// (transição pra INATIVO) e `remove()` já abrem — nunca isoladamente, e
/// nunca lida com `academiaId`/tenant sozinha, por isso recebe `tx`
/// (bypassa a extensão de tenant, igual `gerarMensalidadesDaVigencia`).
///
/// Só ENCERRA o que já existe (muda `status`/`deletedAt`) — nunca cria
/// nada novo, nunca faz `DELETE`. Histórico financeiro/acadêmico
/// (Mensalidade já gerada, Lancamento, AvaliacaoFisica, AulaAluno de aula
/// já realizada) nunca é tocado aqui, de propósito: a regra de negócio é
/// "encerrar o vínculo futuro", não "apagar o passado".
///
/// Idempotente: rodar duas vezes (ex.: arquivar um aluno que já estava
/// arquivado) só encontra zero linhas em cada `updateMany` na segunda vez
/// — nenhum efeito colateral, nenhum erro.
export async function encerrarVinculoDoAluno(
  tx: Prisma.TransactionClient,
  params: { academiaId: string; alunoId: string; userId: string },
): Promise<ResumoEncerramentoVinculo> {
  const { academiaId, alunoId, userId } = params;
  const agora = new Date();

  // 1) Encerrar a Matrícula ATIVA/TRANCADA (docs/32, item 1) — mesmo
  //    efeito de `MatriculasService.cancelar()`, mas como consequência
  //    automática, não uma decisão manual categorizada pelo staff (por
  //    isso `ALUNO_ARQUIVADO`, nunca `ACADEMIA_CANCELOU`).
  const { count: matriculasCanceladas } = await tx.matricula.updateMany({
    where: {
      academiaId,
      alunoId,
      status: { in: [MatriculaStatus.ATIVA, MatriculaStatus.TRANCADA] },
      deletedAt: null,
    },
    data: {
      status: MatriculaStatus.CANCELADA,
      motivoCancelamento: MotivoCancelamento.ALUNO_ARQUIVADO,
      motivoCancelamentoDetalhe: 'Encerrada automaticamente ao arquivar/remover o aluno',
    },
  });

  // 2) Tirar o aluno de toda Turma em que está matriculado (docs/32, item
  //    2) — mesmo efeito de "Sair da turma"
  //    (`TurmaAlunosService.updateStatus(INATIVO)`). Consequência: o
  //    gerador de Aulas (`AulasService.gerar()`, filtra
  //    `TurmaAluno.status = ATIVO`) para de inscrever este aluno em aulas
  //    novas sozinho, sem precisar de nenhuma checagem extra lá.
  const { count: turmaAlunosDesativados } = await tx.turmaAluno.updateMany({
    where: { academiaId, alunoId, status: UserStatus.ATIVO, deletedAt: null },
    data: { status: UserStatus.INATIVO, dataFim: agora },
  });

  // 3) Remover o aluno de aulas FUTURAS já geradas (docs/32, item 2/6) —
  //    soft-delete, nunca as aulas em si. Aulas já realizadas (frequência
  //    passada) nunca são tocadas — só `aula.data >= hoje` entra no filtro.
  //    `AulaStatus` não entra no filtro de propósito: uma aula futura
  //    cancelada também deve soltar o aluno da contagem.
  const hoje = new Date(Date.UTC(agora.getUTCFullYear(), agora.getUTCMonth(), agora.getUTCDate()));
  const { count: aulasFuturasRemovidas } = await tx.aulaAluno.updateMany({
    where: {
      academiaId,
      alunoId,
      deletedAt: null,
      aula: { data: { gte: hoje } },
    },
    data: { deletedAt: agora },
  });

  // 4) Rejeitar solicitação de reposição pendente (docs/32, item 4) — só
  //    PENDENTE; uma já APROVADA já virou uma AulaAluno futura, removida
  //    pelo passo 3 acima.
  const { count: solicitacoesReposicaoRejeitadas } = await tx.solicitacaoReposicao.updateMany({
    where: { academiaId, alunoId, status: SolicitacaoReposicaoStatus.PENDENTE },
    data: {
      status: SolicitacaoReposicaoStatus.REJEITADA,
      motivoRejeicao: 'Aluno arquivado/removido da academia',
      decidedByUserId: userId,
      decidedAt: agora,
    },
  });

  return {
    matriculasCanceladas,
    turmaAlunosDesativados,
    aulasFuturasRemovidas,
    solicitacoesReposicaoRejeitadas,
  };
}
