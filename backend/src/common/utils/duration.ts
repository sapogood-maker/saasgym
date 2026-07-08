const UNIT_TO_MS: Record<string, number> = {
  s: 1000,
  m: 60 * 1000,
  h: 60 * 60 * 1000,
  d: 24 * 60 * 60 * 1000,
};

/// Converte durações simples ("15m", "7d", "1h", "30s") em milissegundos.
/// Usado para o refresh token, cuja expiração é controlada manualmente
/// (não é um JWT — o access token usa o parser da própria @nestjs/jwt).
export function parseDurationToMs(value: string): number {
  const match = /^(\d+)([smhd])$/.exec(value.trim());

  if (!match) {
    throw new Error(`Formato de duração inválido: "${value}" (esperado, ex.: "15m", "7d")`);
  }

  const [, amount, unit] = match;
  return Number(amount) * UNIT_TO_MS[unit];
}
