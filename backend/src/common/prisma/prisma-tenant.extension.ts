import { Prisma } from '@prisma/client';
import { TenantContextService } from '../context/tenant-context.service';

/// Models tenant-scoped que devem ser filtrados automaticamente por
/// academiaId. Só `User` existe hoje — as entidades de negócio (Aluno,
/// Professor, Plano, Agenda, Financeiro...) entram aqui a partir do
/// Sprint 2, e passam a ser protegidas por esta mesma extensão sem
/// precisar de nenhuma mudança nos services que as consultam.
const TENANT_SCOPED_MODELS = new Set(['User']);

const WHERE_OPERATIONS = new Set([
  'findFirst',
  'findFirstOrThrow',
  'findMany',
  'findUnique',
  'findUniqueOrThrow',
  'update',
  'updateMany',
  'delete',
  'deleteMany',
  'count',
  'aggregate',
  'groupBy',
]);

/// Injeta automaticamente `academiaId` (lido do TenantContext, nunca do
/// chamador) em toda query sobre um model tenant-scoped — a defesa de
/// última linha contra um bug em um service vazar dados entre academias.
///
/// SYSTEM_ADMIN (academiaId null no contexto) não é filtrado — precisa
/// enxergar todas as academias para telas de gestão de tenants. Fora de um
/// request autenticado (seed, scripts, testes sem contexto) também não
/// filtra, já que não há tenant algum para aplicar.
export function createTenantExtension(tenantContext: TenantContextService) {
  return Prisma.defineExtension((client) =>
    client.$extends({
      name: 'tenant-isolation',
      query: {
        $allModels: {
          async $allOperations({ model, operation, args, query }) {
            if (!TENANT_SCOPED_MODELS.has(model)) {
              return query(args);
            }

            const academiaId = tenantContext.getAcademiaId();
            if (academiaId === undefined || academiaId === null) {
              return query(args);
            }

            const queryArgs = args as { where?: Record<string, unknown>; data?: unknown };

            if (WHERE_OPERATIONS.has(operation)) {
              queryArgs.where = { ...queryArgs.where, academiaId };
            }

            if (operation === 'create') {
              queryArgs.data = { ...(queryArgs.data as Record<string, unknown>), academiaId };
            }

            if (operation === 'createMany' && Array.isArray((args as { data?: unknown[] }).data)) {
              (args as { data: Record<string, unknown>[] }).data = (
                args as { data: Record<string, unknown>[] }
              ).data.map((item) => ({ ...item, academiaId }));
            }

            // upsert tem forma própria (where + create + update juntos) —
            // não é coberto por WHERE_OPERATIONS nem pelo branch de "create"
            // acima. Sem isso, o branch de update do upsert acharia (e
            // sobrescreveria) um registro de outra academia pelo id, e o
            // branch de create nasceria sem academiaId.
            if (operation === 'upsert') {
              const upsertArgs = args as { where?: Record<string, unknown>; create?: unknown };
              upsertArgs.where = { ...upsertArgs.where, academiaId };
              upsertArgs.create = { ...(upsertArgs.create as Record<string, unknown>), academiaId };
            }

            return query(queryArgs as typeof args);
          },
        },
      },
    }),
  );
}
