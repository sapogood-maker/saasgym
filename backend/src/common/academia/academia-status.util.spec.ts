import { AcademiaStatus } from '@prisma/client';
import { isAcademiaStatusBlocking } from './academia-status.util';

describe('isAcademiaStatusBlocking', () => {
  it.each([AcademiaStatus.TRIAL, AcademiaStatus.ATIVA])('%s não bloqueia', (status) => {
    expect(isAcademiaStatusBlocking(status)).toBe(false);
  });

  it.each([AcademiaStatus.SUSPENSA, AcademiaStatus.BLOQUEADA, AcademiaStatus.CANCELADA])(
    '%s bloqueia',
    (status) => {
      expect(isAcademiaStatusBlocking(status)).toBe(true);
    },
  );
});
