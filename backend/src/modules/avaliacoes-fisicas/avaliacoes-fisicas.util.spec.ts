import { calcularImc } from './avaliacoes-fisicas.util';

describe('calcularImc', () => {
  it('calcula o IMC a partir de peso (kg) e altura (cm)', () => {
    expect(calcularImc(70, 175)).toBeCloseTo(22.9, 1);
  });

  it('arredonda pra 1 casa decimal', () => {
    expect(calcularImc(68, 170)).toBe(23.5);
  });

  it('lida com alturas baixas sem explodir (divisão por número pequeno, não por zero)', () => {
    expect(calcularImc(20, 90)).toBeCloseTo(24.7, 1);
  });
});
