import { Periodicidade } from '@prisma/client';
import { diasEntre, somarDias, somarPeriodicidade } from './matriculas.util';

describe('somarPeriodicidade', () => {
  it.each([
    [Periodicidade.MENSAL, '2026-01-10', '2026-02-10'],
    [Periodicidade.TRIMESTRAL, '2026-01-10', '2026-04-10'],
    [Periodicidade.SEMESTRAL, '2026-01-10', '2026-07-10'],
    [Periodicidade.ANUAL, '2026-01-10', '2027-01-10'],
  ])('%s: %s -> %s', (periodicidade, inicio, esperado) => {
    const resultado = somarPeriodicidade(new Date(inicio), periodicidade);
    expect(resultado.toISOString().slice(0, 10)).toBe(esperado);
  });
});

describe('somarDias', () => {
  it('soma dias corridos a uma data', () => {
    const resultado = somarDias(new Date('2026-01-10'), 5);
    expect(resultado.toISOString().slice(0, 10)).toBe('2026-01-15');
  });
});

describe('diasEntre', () => {
  it('calcula dias corridos entre duas datas, arredondando pra cima', () => {
    const inicio = new Date('2026-01-10T00:00:00.000Z');
    const fim = new Date('2026-01-13T02:00:00.000Z');
    expect(diasEntre(inicio, fim)).toBe(4);
  });

  it('nunca retorna negativo (fim antes do início)', () => {
    const inicio = new Date('2026-01-10T00:00:00.000Z');
    const fim = new Date('2026-01-05T00:00:00.000Z');
    expect(diasEntre(inicio, fim)).toBe(0);
  });
});
