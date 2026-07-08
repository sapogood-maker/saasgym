import { Role } from '@prisma/client';
import { TenantContextService } from './tenant-context.service';
import { AuthenticatedUser } from '../types/authenticated-user.interface';

const userA: AuthenticatedUser = {
  userId: 'user-a',
  academiaId: 'academia-a',
  role: Role.ACADEMIA_ADMIN,
};
const userB: AuthenticatedUser = {
  userId: 'user-b',
  academiaId: 'academia-b',
  role: Role.PROFESSOR,
};

describe('TenantContextService', () => {
  let service: TenantContextService;

  beforeEach(() => {
    service = new TenantContextService();
  });

  it('não tem usuário fora de um contexto', () => {
    expect(service.getUser()).toBeUndefined();
  });

  it('expõe userId/academiaId/role dentro de run()', () => {
    service.run(userA, () => {
      expect(service.getUserId()).toBe('user-a');
      expect(service.getAcademiaId()).toBe('academia-a');
      expect(service.getRole()).toBe(Role.ACADEMIA_ADMIN);
    });
  });

  it('academiaId é null para SYSTEM_ADMIN', () => {
    const systemAdmin: AuthenticatedUser = {
      userId: 'sys',
      academiaId: null,
      role: Role.SYSTEM_ADMIN,
    };
    service.run(systemAdmin, () => {
      expect(service.getAcademiaId()).toBeNull();
    });
  });

  it('isola contextos concorrentes (nunca vaza academiaId entre requisições simultâneas)', async () => {
    const seenA: (string | null | undefined)[] = [];
    const seenB: (string | null | undefined)[] = [];

    const runA = () =>
      service.run(userA, async () => {
        seenA.push(service.getAcademiaId());
        await new Promise((resolve) => setTimeout(resolve, 10));
        seenA.push(service.getAcademiaId());
      });

    const runB = () =>
      service.run(userB, async () => {
        seenB.push(service.getAcademiaId());
        await new Promise((resolve) => setTimeout(resolve, 5));
        seenB.push(service.getAcademiaId());
      });

    await Promise.all([runA(), runB()]);

    expect(seenA).toEqual(['academia-a', 'academia-a']);
    expect(seenB).toEqual(['academia-b', 'academia-b']);
  });

  it('set() aplica o contexto para o restante da execução assíncrona atual (enterWith)', async () => {
    async function simulateRequest() {
      service.set(userA);
      await Promise.resolve();
      return service.getAcademiaId();
    }

    expect(await simulateRequest()).toBe('academia-a');
  });
});
