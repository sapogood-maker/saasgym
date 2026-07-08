# Autenticação

Implementado no Sprint 1 (`backend/src/modules/auth/`). Este documento descreve o que **existe de verdade** — para o desenho original ver `docs/03-fluxo-autenticacao.md`.

## Endpoints

Todos em `/api/auth`, documentados no Swagger (`/api/docs`).

| Endpoint | Acesso | Descrição |
|---|---|---|
| `POST /auth/login` | Público | `{ email, password }` → `{ accessToken, user }` + cookie `refreshToken` |
| `POST /auth/refresh` | Público (via cookie) | Rotaciona o refresh token, devolve novo `{ accessToken }` + novo cookie |
| `POST /auth/logout` | Autenticado | Revoga o refresh token atual, limpa o cookie |
| `GET /auth/me` | Autenticado | Perfil do usuário do token (funciona para `SYSTEM_ADMIN` também — não usa `AcademiaGuard`) |
| `PATCH /auth/password` | Autenticado | Troca a senha, revoga **todas** as sessões do usuário (inclusive a atual) |

## Tokens

- **Access token**: JWT (`@nestjs/jwt`, sem Passport), payload `{ sub, academiaId, role }`, ~15min (`JWT_ACCESS_EXPIRATION`), assinado com `JWT_ACCESS_SECRET`.
- **Refresh token**: opaco — 64 bytes aleatórios (`crypto.randomBytes`), **não é JWT**. Guardado como hash **SHA-256** em `refresh_tokens.tokenHash` (`backend/src/modules/auth/tokens/token.service.ts`). Bcrypt não é usado aqui de propósito: é para segredos de baixa entropia escolhidos por humanos (senhas); um token de 64 bytes já tem entropia suficiente, e refresh acontece com muito mais frequência que login — um hash rápido é a escolha correta.
- Entregue via cookie `httpOnly`; `Secure`+`SameSite=None` em produção, `Secure=false`+`SameSite=Lax` fora de produção (para funcionar em dev local sobre HTTP puro — ver `AuthController.setRefreshCookie`).

## Rotação e detecção de reuso

A cada `/auth/refresh`: o token apresentado é marcado `revokedAt`, um novo é criado, e o antigo aponta para o novo via `replacedBy` (auditoria de quem substituiu quem).

Se um token **já revogado** for reapresentado — sinal de que foi roubado e usado por duas partes —, **todos** os refresh tokens daquele usuário são revogados imediatamente (`AuthService.revokeAllUserTokens`), o evento vira `REFRESH_TOKEN_REUSE_DETECTED` na auditoria, e a sessão original também para de funcionar. Coberto por teste e2e com duas sessões simultâneas (`test/auth.e2e-spec.ts`).

## Trade-off: JWT stateless

`JwtAuthGuard` valida o access token **sem** consultar o banco a cada request — mantém o design stateless para escalar sem round-trip de DB por requisição. Consequência: um access token roubado continua válido até expirar (≤15min), mesmo que a senha tenha sido trocada nesse meio-tempo. Mitigação: o tempo de vida curto do access token + a troca de senha revogar imediatamente todos os *refresh* tokens (a sessão não se renova). Ver `docs/11-security.md`.

## Política de senha

`@IsStrongPassword()` (`backend/src/modules/auth/validators/strong-password.decorator.ts`): mínimo 8 caracteres, com maiúscula, minúscula e número. Aplicado em `ChangePasswordDto.newPassword`.

## Auditoria

Toda ação relevante grava em `audit_logs` (`AuditService.record`, nunca lança erro — falha de auditoria não pode derrubar login/logout/etc.): `LOGIN_SUCCESS`, `LOGIN_FAILURE` (inclusive com e-mail desconhecido — usa um hash "de mentira" para não vazar quais e-mails existem por timing), `LOGOUT`, `PASSWORD_CHANGED`, `REFRESH_TOKEN_USED`, `REFRESH_TOKEN_REUSE_DETECTED`, `SESSION_REVOKED`.

## Sessões

Não existe model `Session` separado — cada `RefreshToken` **é** uma sessão (a cadeia de rotação via `replacedBy` é o histórico daquela sessão). Campos `ipAddress`/`userAgent`/`lastUsedAt` já existem no schema para suportar, no futuro, endpoints de "ver sessões ativas" / "encerrar uma sessão específica" — não implementados neste sprint (não fazem parte dos critérios de aceite), mas a estrutura de dados já suporta sem migration adicional.

## Testando localmente

```bash
cd backend
npm run test          # unitário (guards, services, decorators) — sem banco
npm run test:e2e      # e2e — precisa de DATABASE_URL apontando pra um Postgres real
```

`test/auth.e2e-spec.ts` cobre login (sucesso/falha/validação/auditoria), `/me`, refresh (rotação/reuso), logout (idempotência) e troca de senha — sempre contra um Postgres real, nunca mockado.
