import { Role } from '@prisma/client';

/// Formato de `request.user`, populado pelo JwtAuthGuard a partir do access
/// token. academiaId é nulo apenas para SYSTEM_ADMIN.
export interface AuthenticatedUser {
  userId: string;
  academiaId: string | null;
  role: Role;
}
