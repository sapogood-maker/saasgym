import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';

/// Garante que a rota só seja acessada por usuários vinculados a uma
/// academia (bloqueia SYSTEM_ADMIN, cujo academiaId é sempre null) — use em
/// rotas de negócio tenant-scoped (a partir do Sprint 2).
@Injectable()
export class AcademiaGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user?.academiaId) {
      throw new ForbiddenException('Este recurso exige um usuário vinculado a uma academia');
    }

    return true;
  }
}
