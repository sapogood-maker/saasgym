import { Periodicidade } from '@prisma/client';

const MESES_POR_PERIODICIDADE: Record<Periodicidade, number> = {
  MENSAL: 1,
  TRIMESTRAL: 3,
  SEMESTRAL: 6,
  ANUAL: 12,
};

/// Soma a duração da periodicidade a uma data — usada para calcular
/// dataFimPrevista/dataFim na criação e na renovação. `Date.setMonth` já
/// lida com overflow de mês (ex.: 31/jan + 1 mês vira 3/mar, não 28/fev);
/// aproximação aceita nesta fase, sem calendário comercial dedicado —
/// refinar só se um caso real pedir.
export function somarPeriodicidade(data: Date, periodicidade: Periodicidade): Date {
  const resultado = new Date(data);
  resultado.setMonth(resultado.getMonth() + MESES_POR_PERIODICIDADE[periodicidade]);
  return resultado;
}

export function somarDias(data: Date, dias: number): Date {
  const resultado = new Date(data);
  resultado.setDate(resultado.getDate() + dias);
  return resultado;
}

export function diasEntre(inicio: Date, fim: Date): number {
  return Math.max(0, Math.ceil((fim.getTime() - inicio.getTime()) / (24 * 60 * 60 * 1000)));
}
