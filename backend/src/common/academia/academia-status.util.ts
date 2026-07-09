import { AcademiaStatus } from '@prisma/client';

/// Estados que bloqueiam login/refresh de usuários da academia (ver
/// AuthService e AdminAcademiaService). TRIAL/ATIVA sempre permitem acesso.
export const BLOCKING_ACADEMIA_STATUSES: readonly AcademiaStatus[] = [
  AcademiaStatus.SUSPENSA,
  AcademiaStatus.BLOQUEADA,
  AcademiaStatus.CANCELADA,
];

export function isAcademiaStatusBlocking(status: AcademiaStatus): boolean {
  return BLOCKING_ACADEMIA_STATUSES.includes(status);
}
