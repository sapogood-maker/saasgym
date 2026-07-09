import type { Request } from 'express';

export interface RequestMetadata {
  ipAddress?: string;
  userAgent?: string;
}

/// Extrai IP e User-Agent da requisição para registrar em AuditLog — mesmo
/// par de campos que o AuthController já captura para login/refresh/logout,
/// agora reaproveitado pelos módulos de negócio (Alunos/Professores/Users).
export function requestMetadata(req: Request): RequestMetadata {
  return { ipAddress: req.ip, userAgent: req.headers['user-agent'] };
}
