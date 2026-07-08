# Fluxo de Autenticação

> Implementação prevista para o Sprint 1. Este documento define o contrato desde já para que backend e os dois frontends sejam construídos de forma consistente.

## Perfis (`Role`)

`SYSTEM_ADMIN`, `ACADEMIA_ADMIN`, `RECEPCIONISTA`, `PROFESSOR`, `ALUNO`.

## Estratégia: JWT de acesso + refresh token rotativo

1. **`POST /api/auth/login`** (email + senha) → valida contra `User`, gera:
   - **Access token** (JWT, ~15min, payload `sub`/`role`/`academiaId`), retornado no corpo da resposta.
   - **Refresh token** (opaco, hash salvo em `RefreshToken`, ~7-30 dias), entregue como cookie `httpOnly + Secure + SameSite=None`.
2. O access token fica **em memória** no app Flutter (estado Riverpod em `shared_core`, `authSessionProvider`) — nunca em `localStorage`, para reduzir superfície de roubo via XSS. O refresh token nunca é acessível ao JavaScript do frontend.
3. **`POST /api/auth/refresh`** — valida o cookie, **rotaciona** o refresh token (revoga o antigo, emite um novo) e devolve um novo access token. Reuso de um refresh token já revogado é tratado como possível roubo e revoga toda a sessão do usuário.
4. **`POST /api/auth/logout`** — revoga o refresh token atual.

## Autorização por requisição

- `JwtAuthGuard` valida o access token em toda rota protegida.
- `RolesGuard` + `@Roles(Role.ACADEMIA_ADMIN, Role.RECEPCIONISTA)` no controller define quem acessa cada endpoint.
- `@CurrentUser()` e `@TenantId()` expõem o usuário e o `academiaId` autenticado ao service.
- `SYSTEM_ADMIN` usa um guard próprio (`@SystemAdminOnly`) para endpoints de gestão de academias.

Estrutura pensada para evoluir de "role fixo" para permissões finas (tabela `Permission`) sem quebrar o contrato dos guards — o guard consulta um `PermissionService` que hoje retorna um mapa estático role→permissões.

## Por que cookie httpOnly para o refresh token

Os dois frontends (`admin_web`, `student_web`) e a API rodam em subdomínios do mesmo domínio em produção, o que permite cookies `SameSite=None; Secure` funcionarem entre eles. Isso evita que o refresh token — de vida longa — fique exposto a qualquer script rodando na página, ao contrário de `localStorage`.

## Fora do MVP (reservado, não bloqueia o início)

- Fluxo de "esqueci minha senha" (endpoint reservado no módulo `auth`).
- Tabela `Permission` para granularidade além de `role`.
