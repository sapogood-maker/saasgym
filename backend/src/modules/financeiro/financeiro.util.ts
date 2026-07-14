/// Intervalo [início, fim) do mês/ano informado, em UTC — usado tanto por
/// Mensalidades (checar se já existe cobrança gerada pro período, filtro
/// de listagem por mês) quanto por Lançamentos (filtro de listagem e
/// resumo do Caixa por competência). `fim` é o primeiro dia do mês
/// seguinte (exclusivo), não o último instante do mês — evita off-by-one
/// em comparações `gte`/`lt` no Prisma.
export function intervaloDoMes(mes: number, ano: number): { inicio: Date; fim: Date } {
  const inicio = new Date(Date.UTC(ano, mes - 1, 1));
  const fim = new Date(Date.UTC(mes === 12 ? ano + 1 : ano, mes === 12 ? 0 : mes, 1));
  return { inicio, fim };
}

/// Mês/ano `quantidade` meses antes do informado — usado pela janela de
/// "evolução mensal" do Painel Financeiro (MS5): a âncora (quantidade=0)
/// é o próprio mês informado, quantidade=1 é o mês anterior, etc.
/// Aproveita o overflow do JS `Date` pra virar o ano corretamente (mesma
/// aproximação já aceita em `mensalidades.util.ts#dataVencimentoNoMes`).
export function mesRecuado(mes: number, ano: number, quantidade: number): { mes: number; ano: number } {
  const data = new Date(Date.UTC(ano, mes - 1 - quantidade, 1));
  return { mes: data.getUTCMonth() + 1, ano: data.getUTCFullYear() };
}
