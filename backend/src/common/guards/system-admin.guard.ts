import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Role } from '@prisma/client';

/// Restringe o acesso exclusivamente ao SYSTEM_ADMIN — uso em endpoints de
/// gestão de academias (tenants), nunca em rotas de negócio.
@Injectable()
export class SystemAdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (user?.role !== Role.SYSTEM_ADMIN) {
      throw new ForbiddenException('Recurso restrito ao administrador do sistema');
    }

    return true;
  }
}
