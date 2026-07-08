import { parseDurationToMs } from './duration';

describe('parseDurationToMs', () => {
  it.each([
    ['30s', 30 * 1000],
    ['15m', 15 * 60 * 1000],
    ['1h', 60 * 60 * 1000],
    ['7d', 7 * 24 * 60 * 60 * 1000],
  ])('%s -> %dms', (input, expected) => {
    expect(parseDurationToMs(input)).toBe(expected);
  });

  it('lança para formato inválido', () => {
    expect(() => parseDurationToMs('7 dias')).toThrow();
    expect(() => parseDurationToMs('')).toThrow();
    expect(() => parseDurationToMs('10x')).toThrow();
  });
});
