import { RecorrenciaTipo } from '@prisma/client';

/// Todo cálculo de data aqui é em UTC (`getUTCDay`/`Date.UTC`/etc.), nunca
/// em fuso local — as datas de `Recorrencia`/`Aula` nascem de um
/// `IsDateString` ("2026-08-01") parseado como meia-noite UTC (mesmo
/// padrão já usado em `MatriculasService`), e a comparação de igualdade
/// usada pra idempotência (`(recorrenciaId, data)`) só funciona se todo
/// mundo gerar exatamente o mesmo instante UTC pro "mesmo dia".
export interface RecorrenciaParaCalculo {
  tipo: RecorrenciaTipo;
  diaSemana: number | null;
  diaDoMes: number | null;
  intervaloDias: number | null;
  dataInicioVigencia: Date;
  dataFimVigencia: Date | null;
}

function inicioDoDiaUtc(data: Date): Date {
  return new Date(Date.UTC(data.getUTCFullYear(), data.getUTCMonth(), data.getUTCDate()));
}

function maxData(a: Date, b: Date): Date {
  return a.getTime() > b.getTime() ? a : b;
}

function minData(a: Date, b: Date): Date {
  return a.getTime() < b.getTime() ? a : b;
}

/// Datas candidatas de uma Recorrência dentro de `[inicioPeriodo,
/// fimPeriodo]` — antes do filtro de `Feriado` (docs/18, seção 5,
/// "Geração de Aulas", passos 2-3). A vigência da Recorrência sempre
/// restringe o período pedido (nunca gera fora de `dataInicioVigencia`/
/// `dataFimVigencia`), exceto o ponto de partida do cálculo `INTERVALADA`,
/// que usa sempre `dataInicioVigencia` como âncora (não o início efetivo
/// clampeado) — mesma regra do fluxo documentado.
export function calcularDatasCandidatas(
  recorrencia: RecorrenciaParaCalculo,
  inicioPeriodo: Date,
  fimPeriodo: Date,
): Date[] {
  const dataInicioVigencia = inicioDoDiaUtc(recorrencia.dataInicioVigencia);
  const inicioEfetivo = maxData(dataInicioVigencia, inicioDoDiaUtc(inicioPeriodo));
  const fimEfetivo = recorrencia.dataFimVigencia
    ? minData(inicioDoDiaUtc(recorrencia.dataFimVigencia), inicioDoDiaUtc(fimPeriodo))
    : inicioDoDiaUtc(fimPeriodo);

  if (inicioEfetivo.getTime() > fimEfetivo.getTime()) {
    return [];
  }

  switch (recorrencia.tipo) {
    case RecorrenciaTipo.SEMANAL:
      return datasSemanais(recorrencia.diaSemana as number, inicioEfetivo, fimEfetivo);
    case RecorrenciaTipo.MENSAL:
      return datasMensais(recorrencia.diaDoMes as number, inicioEfetivo, fimEfetivo);
    case RecorrenciaTipo.INTERVALADA:
      return datasIntervaladas(
        dataInicioVigencia,
        recorrencia.intervaloDias as number,
        inicioEfetivo,
        fimEfetivo,
      );
  }
}

function datasSemanais(diaSemana: number, inicio: Date, fim: Date): Date[] {
  const datas: Date[] = [];
  const cursor = new Date(inicio);
  while (cursor.getTime() <= fim.getTime()) {
    if (cursor.getUTCDay() === diaSemana) {
      datas.push(new Date(cursor));
    }
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return datas;
}

/// Um candidato por mês — meses onde `diaDoMes` não existe (ex.: 31 em
/// abril) não geram ocorrência naquele mês, sem "rolar" pro mês seguinte
/// (`Date.UTC` faria isso silenciosamente; aqui é detectado e descartado).
function datasMensais(diaDoMes: number, inicio: Date, fim: Date): Date[] {
  const datas: Date[] = [];
  let ano = inicio.getUTCFullYear();
  let mes = inicio.getUTCMonth();
  const anoFim = fim.getUTCFullYear();
  const mesFim = fim.getUTCMonth();

  while (ano < anoFim || (ano === anoFim && mes <= mesFim)) {
    const candidato = new Date(Date.UTC(ano, mes, diaDoMes));
    if (candidato.getUTCMonth() === mes) {
      if (candidato.getTime() >= inicio.getTime() && candidato.getTime() <= fim.getTime()) {
        datas.push(candidato);
      }
    }
    mes += 1;
    if (mes > 11) {
      mes = 0;
      ano += 1;
    }
  }
  return datas;
}

function datasIntervaladas(ancora: Date, intervaloDias: number, inicio: Date, fim: Date): Date[] {
  const datas: Date[] = [];
  const cursor = new Date(ancora);
  while (cursor.getTime() <= fim.getTime()) {
    if (cursor.getTime() >= inicio.getTime()) {
      datas.push(new Date(cursor));
    }
    cursor.setUTCDate(cursor.getUTCDate() + intervaloDias);
  }
  return datas;
}

export function formatarDataChave(data: Date): string {
  return inicioDoDiaUtc(data).toISOString();
}
