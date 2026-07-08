import { createParamDecorator, ExecutionContext } from '@nestjs/common';

/// academiaId do usuário autenticado (null para SYSTEM_ADMIN) — nunca vem
/// do corpo/query da requisição.
export const CurrentAcademia = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): string | null => {
    const request = ctx.switchToHttp().getRequest();
    return request.user?.academiaId ?? null;
  },
);
