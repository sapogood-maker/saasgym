/// Data de vencimento dentro do mês/ano alvo, no dia combinado na
/// Matricula. `Date.UTC` já satura meses com menos dias que `diaVencimento`
/// pro próprio overflow do JS (ex.: dia 31 num mês de 30 dias vira o dia 1
/// do mês seguinte) — mesma aproximação aceita em
/// `matriculas.util.ts#somarPeriodicidade`, sem calendário comercial
/// dedicado.
export function dataVencimentoNoMes(mes: number, ano: number, diaVencimento: number): Date {
  return new Date(Date.UTC(ano, mes - 1, diaVencimento));
}

/// valor líquido de uma Mensalidade — sempre calculado, nunca armazenado
/// (docs/17-modulo-3-financeiro-analise.md, item 6).
export function valorFinal(valor: number, desconto: number, multa: number): number {
  return Math.round((valor - desconto + multa) * 100) / 100;
}
