import { SetMetadata } from '@nestjs/common';
import { Role } from '@prisma/client';

export const ROLES_KEY = 'roles';

/// Restringe um endpoint a um ou mais perfis. Usado com RolesGuard.
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);
