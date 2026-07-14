import { dataVencimentoNoMes, valorFinal } from './mensalidades.util';

describe('dataVencimentoNoMes', () => {
  it('monta a data de vencimento no dia combinado', () => {
    expect(dataVencimentoNoMes(7, 2026, 10).toISOString().slice(0, 10)).toBe('2026-07-10');
  });

  it('satura meses mais curtos que o dia combinado (overflow do JS Date)', () => {
    // Fevereiro/2026 tem 28 dias — dia 31 estoura pro início de março.
    expect(dataVencimentoNoMes(2, 2026, 31).toISOString().slice(0, 10)).toBe('2026-03-03');
  });
});

describe('valorFinal', () => {
  it('subtrai desconto e soma multa', () => {
    expect(valorFinal(150, 20, 0)).toBe(130);
    expect(valorFinal(150, 0, 15)).toBe(165);
  });

  it('arredonda pra 2 casas decimais', () => {
    expect(valorFinal(150.456, 0, 0)).toBe(150.46);
  });
});
