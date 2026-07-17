import { Prisma } from '@prisma/client';

/// Data de vencimento dentro do mês/ano alvo, no dia combinado na
/// Matricula. `Date.UTC` já satura meses com menos dias que `diaVencimento`
/// pro próprio overflow do JS (ex.: dia 31 num mês de 30 dias vira o dia 1
/// do mês seguinte) — mesma aproximação aceita em
/// `matriculas.util.ts#somarPeriodicidade`, sem calendário comercial
/// dedicado.
export function dataVencimentoNoMes(mes: number, ano: number, diaVencimento: number): Date {
  return new Date(Date.UTC(ano, mes - 1, diaVencimento));
}

/// Um item por mês civil coberto por [dataInicio, dataFimPrevista) — mesma
/// cadência mensal de cobrança já usada em `gerar()` (docs/17, item 3:
/// "Mensalidade é sempre mensal, independente da periodicidade do Plano").
/// Não depende de `Periodicidade` nem lê o Plano — só das próprias datas da
/// Matricula (Sprint de Integridade Financeira, docs/29, item 1).
function mesesDaVigencia(dataInicio: Date, dataFimPrevista: Date): { mes: number; ano: number }[] {
  const meses: { mes: number; ano: number }[] = [];
  const cursor = new Date(Date.UTC(dataInicio.getUTCFullYear(), dataInicio.getUTCMonth(), 1));
  const limite = new Date(
    Date.UTC(dataFimPrevista.getUTCFullYear(), dataFimPrevista.getUTCMonth(), 1),
  );
  while (cursor.getTime() < limite.getTime()) {
    meses.push({ mes: cursor.getUTCMonth() + 1, ano: cursor.getUTCFullYear() });
    cursor.setUTCMonth(cursor.getUTCMonth() + 1);
  }
  return meses;
}

/// Gera de uma vez todas as `Mensalidade` da vigência de uma Matricula —
/// chamado dentro da mesma transação que cria a Matricula (`create()`) ou a
/// renova (`renovar()`), nunca fora dela (docs/29, item 4: a matrícula
/// nunca deve existir sem suas cobranças já geradas). `valor`/
/// `diaVencimento` vêm de quem chama (sempre a própria Matricula, nunca do
/// Plano — mesmo princípio do item 1). `skipDuplicates` depende da
/// constraint `@@unique([matriculaId, dataVencimento])` em `Mensalidade`
/// (docs/29, item 5) — sem ela, seria só uma proteção de aplicação, não de
/// banco.
export async function gerarMensalidadesDaVigencia(
  tx: Prisma.TransactionClient,
  params: {
    academiaId: string;
    matriculaId: string;
    alunoId: string;
    valor: number;
    diaVencimento: number;
    dataInicio: Date;
    dataFimPrevista: Date;
    createdByUserId: string;
  },
): Promise<number> {
  const meses = mesesDaVigencia(params.dataInicio, params.dataFimPrevista);
  if (meses.length === 0) {
    return 0;
  }

  const resultado = await tx.mensalidade.createMany({
    data: meses.map(({ mes, ano }) => ({
      academiaId: params.academiaId,
      matriculaId: params.matriculaId,
      alunoId: params.alunoId,
      valor: params.valor,
      dataVencimento: dataVencimentoNoMes(mes, ano, params.diaVencimento),
      createdByUserId: params.createdByUserId,
    })),
    skipDuplicates: true,
  });
  return resultado.count;
}

/// valor líquido de uma Mensalidade — sempre calculado, nunca armazenado
/// (docs/17-modulo-3-financeiro-analise.md, item 6).
export function valorFinal(valor: number, desconto: number, multa: number): number {
  return Math.round((valor - desconto + multa) * 100) / 100;
}
