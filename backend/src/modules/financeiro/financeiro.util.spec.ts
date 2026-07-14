import { intervaloDoMes, mesRecuado } from './financeiro.util';

describe('intervaloDoMes', () => {
  it('retorna o 1º dia do mês (inclusive) até o 1º dia do mês seguinte (exclusivo)', () => {
    const { inicio, fim } = intervaloDoMes(7, 2026);
    expect(inicio.toISOString()).toBe('2026-07-01T00:00:00.000Z');
    expect(fim.toISOString()).toBe('2026-08-01T00:00:00.000Z');
  });

  it('vira o ano corretamente em dezembro', () => {
    const { inicio, fim } = intervaloDoMes(12, 2026);
    expect(inicio.toISOString()).toBe('2026-12-01T00:00:00.000Z');
    expect(fim.toISOString()).toBe('2027-01-01T00:00:00.000Z');
  });
});

describe('mesRecuado', () => {
  it('quantidade=0 retorna o próprio mês/ano (âncora)', () => {
    expect(mesRecuado(7, 2026, 0)).toEqual({ mes: 7, ano: 2026 });
  });

  it('volta meses dentro do mesmo ano', () => {
    expect(mesRecuado(7, 2026, 3)).toEqual({ mes: 4, ano: 2026 });
  });

  it('vira o ano corretamente ao voltar além de janeiro', () => {
    expect(mesRecuado(2, 2026, 3)).toEqual({ mes: 11, ano: 2025 });
  });

  it('volta vários anos quando a janela é grande', () => {
    expect(mesRecuado(1, 2026, 13)).toEqual({ mes: 12, ano: 2024 });
  });
});
