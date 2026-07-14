import { RecorrenciaTipo } from '@prisma/client';
import { calcularDatasCandidatas } from './aulas.util';

function d(iso: string): Date {
  return new Date(iso);
}

function isoDatas(datas: Date[]): string[] {
  return datas.map((data) => data.toISOString().slice(0, 10));
}

describe('calcularDatasCandidatas', () => {
  describe('SEMANAL', () => {
    it('gera uma data por semana no dia da semana configurado', () => {
      const recorrencia = {
        tipo: RecorrenciaTipo.SEMANAL,
        diaSemana: 1, // segunda-feira
        diaDoMes: null,
        intervaloDias: null,
        dataInicioVigencia: d('2026-08-01'),
        dataFimVigencia: null,
      };

      const datas = calcularDatasCandidatas(recorrencia, d('2026-08-01'), d('2026-08-31'));

      expect(isoDatas(datas)).toEqual(['2026-08-03', '2026-08-10', '2026-08-17', '2026-08-24', '2026-08-31']);
    });

    it('respeita dataFimVigencia mesmo quando o período pedido vai além', () => {
      const recorrencia = {
        tipo: RecorrenciaTipo.SEMANAL,
        diaSemana: 1,
        diaDoMes: null,
        intervaloDias: null,
        dataInicioVigencia: d('2026-08-01'),
        dataFimVigencia: d('2026-08-15'),
      };

      const datas = calcularDatasCandidatas(recorrencia, d('2026-08-01'), d('2026-08-31'));

      expect(isoDatas(datas)).toEqual(['2026-08-03', '2026-08-10']);
    });

    it('respeita dataInicioVigencia mesmo quando o período pedido começa antes', () => {
      const recorrencia = {
        tipo: RecorrenciaTipo.SEMANAL,
        diaSemana: 1,
        diaDoMes: null,
        intervaloDias: null,
        dataInicioVigencia: d('2026-08-11'),
        dataFimVigencia: null,
      };

      const datas = calcularDatasCandidatas(recorrencia, d('2026-08-01'), d('2026-08-31'));

      expect(isoDatas(datas)).toEqual(['2026-08-17', '2026-08-24', '2026-08-31']);
    });

    it('período pedido totalmente fora da vigência retorna vazio', () => {
      const recorrencia = {
        tipo: RecorrenciaTipo.SEMANAL,
        diaSemana: 1,
        diaDoMes: null,
        intervaloDias: null,
        dataInicioVigencia: d('2026-09-01'),
        dataFimVigencia: null,
      };

      const datas = calcularDatasCandidatas(recorrencia, d('2026-08-01'), d('2026-08-31'));

      expect(datas).toEqual([]);
    });
  });

  describe('MENSAL', () => {
    it('gera uma data por mês no dia do mês configurado', () => {
      const recorrencia = {
        tipo: RecorrenciaTipo.MENSAL,
        diaSemana: null,
        diaDoMes: 15,
        intervaloDias: null,
        dataInicioVigencia: d('2026-08-01'),
        dataFimVigencia: null,
      };

      const datas = calcularDatasCandidatas(recorrencia, d('2026-08-01'), d('2026-10-31'));

      expect(isoDatas(datas)).toEqual(['2026-08-15', '2026-09-15', '2026-10-15']);
    });

    it('pula meses onde o dia do mês não existe (31 em abril), sem rolar pro mês seguinte', () => {
      const recorrencia = {
        tipo: RecorrenciaTipo.MENSAL,
        diaSemana: null,
        diaDoMes: 31,
        intervaloDias: null,
        dataInicioVigencia: d('2026-03-01'),
        dataFimVigencia: null,
      };

      const datas = calcularDatasCandidatas(recorrencia, d('2026-03-01'), d('2026-05-31'));

      // Março e maio têm dia 31; abril não tem — não deve gerar 1/mai no lugar.
      expect(isoDatas(datas)).toEqual(['2026-03-31', '2026-05-31']);
    });
  });

  describe('INTERVALADA', () => {
    it('gera datas a partir de dataInicioVigencia + k * intervaloDias', () => {
      const recorrencia = {
        tipo: RecorrenciaTipo.INTERVALADA,
        diaSemana: null,
        diaDoMes: null,
        intervaloDias: 14,
        dataInicioVigencia: d('2026-08-01'),
        dataFimVigencia: null,
      };

      const datas = calcularDatasCandidatas(recorrencia, d('2026-08-01'), d('2026-09-30'));

      expect(isoDatas(datas)).toEqual(['2026-08-01', '2026-08-15', '2026-08-29', '2026-09-12', '2026-09-26']);
    });

    it('âncora do intervalo é sempre dataInicioVigencia, mesmo se o período pedido começar depois', () => {
      const recorrencia = {
        tipo: RecorrenciaTipo.INTERVALADA,
        diaSemana: null,
        diaDoMes: null,
        intervaloDias: 14,
        dataInicioVigencia: d('2026-08-01'),
        dataFimVigencia: null,
      };

      // Pedindo só a partir de 20/ago — mas a série continua ancorada em 1/ago
      // (15, 29), não recalculada a partir de 20/ago.
      const datas = calcularDatasCandidatas(recorrencia, d('2026-08-20'), d('2026-09-30'));

      expect(isoDatas(datas)).toEqual(['2026-08-29', '2026-09-12', '2026-09-26']);
    });
  });

  describe('idempotência do cálculo', () => {
    it('chamar a função duas vezes com os mesmos parâmetros produz exatamente o mesmo resultado', () => {
      const recorrencia = {
        tipo: RecorrenciaTipo.SEMANAL,
        diaSemana: 3,
        diaDoMes: null,
        intervaloDias: null,
        dataInicioVigencia: d('2026-08-01'),
        dataFimVigencia: null,
      };

      const primeira = calcularDatasCandidatas(recorrencia, d('2026-08-01'), d('2026-08-31'));
      const segunda = calcularDatasCandidatas(recorrencia, d('2026-08-01'), d('2026-08-31'));

      expect(isoDatas(primeira)).toEqual(isoDatas(segunda));
    });
  });
});
