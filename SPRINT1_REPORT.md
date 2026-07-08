# SaaSGym — Relatório Final do Sprint 1 (Autenticação, Autorização e Multi-Tenant)

**Data:** 2026-07-08
**Escopo:** camada completa de identidade, autenticação, autorização e isolamento entre academias — sem nenhum módulo de negócio (Alunos, Agenda, Financeiro etc.), conforme delimitado.
**Commit:** `aa27e5a` (branch `main`) — CI verde no GitHub Actions.

---

## 1. Arquitetura implementada

```
backend/src/
├── common/
│   ├── context/          TenantContext (AsyncLocalStorage) + módulo global
│   ├── decorators/       @Public @Roles @CurrentUser @CurrentAcademia
│   ├── filters/          AllExceptionsFilter (global)
│   ├── guards/           JwtAuthGuard RolesGuard AcademiaGuard SystemAdminGuard
│   ├── interceptors/     TenantContextInterceptor (global)
│   ├── prisma/           extensão de isolamento por tenant (forTenant())
│   ├── types/            AuthenticatedUser
│   └── utils/            parseDurationToMs
└── modules/
    ├── audit/            AuditService (grava em audit_logs, nunca lança)
    └── auth/
        ├── auth.controller.ts / auth.service.ts / auth.module.ts
        ├── dto/          LoginDto, ChangePasswordDto, UserProfileDto
        ├── tokens/        TokenService (JWT + refresh opaco+SHA-256)
        └── validators/    @IsStrongPassword()
```

**Decisões arquiteturais e por quê** (validadas com o usuário antes de codar — ver histórico de planejamento):

- **`Academia`/`academiaId` mantidos** (não renomeado para "Organization") — preserva a fundação do Sprint 0 sem alteração estrutural injustificada.
- **JWT sem Passport** — guard customizado usando `@nestjs/jwt` diretamente. Mais enxuto que reintroduzir `@nestjs/passport`/`passport`/`passport-jwt` (removidos no Sprint 0 por estarem sem uso) para um único mecanismo de autenticação.
- **TenantContext via Interceptor, não via `enterWith()` no Guard** — a abordagem original planejada (guard populando o contexto com `enterWith()`) foi **provada incorreta por um teste** durante a implementação: `enterWith()` chamado depois de um `await` interno não propaga de volta para quem chamou. Corrigido com um interceptor que envolve a *subscription* do handler em `AsyncLocalStorage.run()`. Ver `docs/12-multi-tenant.md` para a explicação técnica completa — é o achado mais importante deste sprint do ponto de vista de arquitetura.
- **Refresh token hasheado com SHA-256, não bcrypt** — bcrypt é para segredos de baixa entropia escolhidos por humanos (senhas); um token aleatório de 64 bytes já tem entropia suficiente, e um hash rápido é a escolha correta para uma operação (`/auth/refresh`) que acontece com muito mais frequência que login.

## 2. Endpoints criados

| Endpoint | Acesso | Rate limit |
|---|---|---|
| `POST /api/auth/login` | Público | 5/min por IP (produção) |
| `POST /api/auth/refresh` | Público (via cookie) | 60/min (global) |
| `POST /api/auth/logout` | Autenticado | 60/min (global) |
| `GET /api/auth/me` | Autenticado | 60/min (global) |
| `PATCH /api/auth/password` | Autenticado | 60/min (global) |

Todos documentados no Swagger (`/api/docs`), confirmado manualmente via Docker real.

## 3. Fluxo de autenticação

Ver `docs/10-auth.md` para o documento completo. Resumo: login emite access token JWT (~15min) + refresh token opaco via cookie `httpOnly`; refresh rotaciona o token a cada uso e detecta reuso de token revogado (indício de roubo) revogando toda a família de sessões do usuário; troca de senha revoga todas as sessões, inclusive a atual. Todo evento é auditado.

## 4. Cobertura de testes

**87 testes, todos passando** — 56 unitários (sem banco) + 31 e2e (Postgres real), confirmados de forma independente: localmente via container Docker isolado, numa simulação completa da sequência do CI, no próprio GitHub Actions (runner genuinamente zerado), e mais uma vez após a revisão arquitetural pré-`v0.2.0`.

| Camada | O que cobre |
|---|---|
| Guards (unit) | `JwtAuthGuard`, `RolesGuard`, `AcademiaGuard`, `SystemAdminGuard` — cada combinação de permissão, isoladamente |
| Guards (integração HTTP) | Os 4 guards juntos, via um controller de teste isolado, nunca registrado no app real |
| `TenantContextService` | Isolamento entre contextos concorrentes (duas "requisições" simultâneas nunca vazam `academiaId` uma pra outra) |
| `TenantContextInterceptor` | Contexto sobrevive a um `await` interno no handler (o cenário exato que quebrava com `enterWith()`); cancelamento (`unsubscribe`) propaga para o handler interno |
| `TokenService` | Geração/hash de tokens, unicidade, determinismo do hash |
| `AuditService` | Grava corretamente e nunca propaga erro de escrita |
| `ThrottlerGuard` | 429 real após o limite, via HTTP |
| Extensão do Prisma | 10 cenários: sem contexto, `SYSTEM_ADMIN`, isolamento entre academias, `create`/`createMany` automáticos, `count()`, `findUnique`/`update`/`delete`/`upsert` nunca alcançando registro de outra academia, client "cru" intencionalmente sem filtro |
| `auth.e2e-spec.ts` | Login (sucesso/falha/e-mail inexistente/validação/auditoria), `/me`, refresh (rotação/reuso derrubando todas as sessões), logout (idempotência), troca de senha (política/senha errada/sucesso) |

## 5. Riscos encontrados e corrigidos durante a implementação

| # | Achado | Como foi pego | Correção |
|---|---|---|---|
| 1 | `AsyncLocalStorage.enterWith()` dentro de um guard `async` não propaga o contexto para quem chamou, se houver um `await` antes | Teste unitário do `JwtAuthGuard` falhou de forma inesperada | Movido para um `TenantContextInterceptor` com `AsyncLocalStorage.run()` envolvendo a subscription do handler |
| 2 | `POST /auth/login` retornava `201 Created` (padrão do Nest para `@Post()`), não `200` como documentado | Teste e2e falhou | `@HttpCode(HttpStatus.OK)` explícito |
| 3 | Comparar `accessToken` novo vs. antigo no teste de refresh falhava às vezes — JWTs com o mesmo payload emitidos no mesmo segundo (`iat` em segundos) saem byte-idênticos | Teste e2e flaky | Não é bug da aplicação — corrigida a asserção do teste, que comparava a coisa errada |
| 4 | Rate limit de login (5/min) derrubava a própria suíte e2e, que faz dezenas de logins em segundos | 10 testes falharam com 429 de uma hora pra outra | Limite sobe para 1000/min quando `NODE_ENV=test`, mantendo 5/min real em produção (confirmado via Docker) |
| 5 | Mensagem de erro customizada da validação de segredo fraco nunca aparecia (herdado do Sprint 0, reexposto ao escrever o primeiro teste unitário real do projeto) | Teste unitário novo | `errors.toString()` do `class-validator` ignora `message` customizada — corrigido para montar a mensagem a partir de `error.constraints` |
| 6 | `npm ci` corrompido dentro de um container por queda de rede no ambiente de teste (não é um bug do projeto) | `test:e2e` falhou com "jest: not found" | Limpeza do volume Docker e novo `npm ci` — documentado aqui só para constar que não é um problema de código |

Todos os 6 itens foram corrigidos e reverificados. O item 1 é o mais relevante: é exatamente o tipo de bug sutil (comportamento assíncrono do Node) que passaria despercebido sem um teste escrito especificamente para provar a propagação do contexto.

## 6. Avaliação de segurança

- Senhas: bcrypt custo 10, política mínima (8+ caracteres, maiúscula, minúscula, número), timing-safe contra enumeração de e-mail.
- Tokens: access JWT curto, refresh opaco de alta entropia, rotação com detecção de reuso, revogação em cascata na troca de senha.
- Rede: Helmet (CSP, sem `X-Powered-By`, etc.), CORS restrito a origens explícitas, `trust proxy` para IP real atrás do Coolify/Traefik.
- Abuso: rate limiting global + específico no login, confirmado via 429 real em produção (Docker).
- Erros: nunca vazam stack trace, em nenhum ambiente.
- Isolamento: `academiaId` nunca aceito do cliente, sempre derivado do JWT; extensão do Prisma como defesa de última linha.
- Trade-off documentado (não omissão): JWT stateless significa que um access token vazado continua válido até expirar (≤15min) mesmo após troca de senha — mitigado pelo tempo de vida curto e pela revogação imediata de todos os refresh tokens.
- Riscos aceitos e documentados: rate limiting em memória (não compartilhado entre réplicas — não é problema na escala atual), vulnerabilidades conhecidas em `qs`/`body-parser`/`express` (herdadas do Sprint 0, exigem NestJS v11).

## 7. Avaliação de arquitetura

- Separação limpa entre infraestrutura reutilizável (`common/`) e módulos de domínio (`modules/auth`, `modules/audit`) — o padrão que `modules/aluno`, `modules/agenda` etc. vão seguir a partir do Sprint 2.
- Nenhuma dependência de negócio vazou para dentro de `common/` — guards, decorators e a extensão do Prisma são genéricos, prontos para qualquer entidade tenant-scoped futura sem modificação.
- Escopo respeitado à risca: nenhum módulo de negócio foi tocado; `RolesGuard`/`AcademiaGuard` foram construídos e testados exaustivamente mesmo sem um endpoint real para "pendurar" ainda — o uso em produção começa no Sprint 2, deixado explícito na documentação em vez de forçar um endpoint fora de escopo só para exercitá-los.
- Zero atalhos: todo fluxo (login, refresh, logout, troca de senha) passa por auditoria, e todo teste roda contra Postgres real, nunca mockado no nível de integração.

## 7.1. Revisão arquitetural pré-`v0.2.0`

Antes de considerar a camada de autenticação congelada, foi feita uma segunda passada dedicada por todo o código do sprint (não só o que os testes já cobriam), procurando especificamente por segurança, acoplamento, duplicação, distribuição de responsabilidades, performance e riscos para os módulos de negócio que vêm a seguir. Achados reais, todos corrigidos e revalidados (build + lint + 56 testes unitários + 31 e2e + verificação manual completa contra Docker real):

| # | Achado | Risco se não corrigido | Correção |
|---|---|---|---|
| 1 | A extensão de isolamento do Prisma não tratava `upsert` — nem o `where` nem o `create` eram filtrados por `academiaId` | **Real e confirmado por teste**: o branch de update do `upsert` conseguia achar e sobrescrever um registro de **outra** academia pelo id, ignorando o isolamento por completo | Tratamento dedicado para `upsert` na extensão (injeta `academiaId` no `where` e no `create`); `groupBy` também adicionado à lista de operações filtradas por `where` |
| 2 | `TokenService.verifyAccessToken()` existia, era testado, mas nunca era chamado — `JwtAuthGuard` reimplementava a mesma verificação direto via `JwtService`/`ConfigService` | Duplicação real: duas implementações da mesma lógica podiam divergir silenciosamente (ex.: ao implementar rotação de chave, seria fácil atualizar uma e esquecer a outra) | Método morto removido do `TokenService` (e seu teste); `JwtAuthGuard` continua com sua própria verificação — única fonte da verdade agora |
| 3 | `TenantContextInterceptor` não propagava `unsubscribe()` para a subscription interna do handler | Requisição cancelada/cliente lento desconectando não interrompe o handler em andamento no servidor — vazamento de recurso sob carga sustentada | `new Observable` agora retorna uma função de teardown que desinscreve a subscription interna; coberto por teste dedicado |
| 4 | `TenantContextService.set()` (baseado em `enterWith()`) era código morto, nunca chamado em produção — mas o comentário da classe ainda dizia que era assim que o `JwtAuthGuard` populava o contexto, e havia um teste "provando" que funcionava | O teste testava um cenário diferente do bug real (await *dentro* da mesma função, não através de uma fronteira guard→continuação) — dava falsa confiança para alguém reintroduzir exatamente o bug do Achado #1 do Sprint 1 (`enterWith()` não propaga através de `await`) em um contexto novo (ex.: um job assíncrono, um handler de WebSocket) | `set()` removido; documentação da classe corrigida para apontar o `TenantContextInterceptor` como o único mecanismo válido |
| 5 | `PrismaService.forTenant()` construía uma nova instância do client estendido a cada chamada, mesmo várias vezes dentro da mesma requisição | Alocação desnecessária repetida em todo request de negócio a partir do Sprint 2 (sem benefício — o filtro já é resolvido em tempo de query, não em tempo de construção do client) | Instância cacheada no `PrismaService`, construída uma única vez |

**Verificado e confirmado correto** (nada mudou, mas valia a pena checar de verdade em vez de assumir):
- `findUnique`/`update`/`delete` com `academiaId` mesclado no `where` junto de um identificador único funcionam exatamente como esperado — Prisma suporta "extended where unique" nesses casos. Sem essa verificação empírica, essa era a maior incerteza da extensão.
- A ordem de execução dos guards globais é `ThrottlerGuard` → `JwtAuthGuard`: uma rajada de requisições sem token válido contra uma rota protegida é contada pelo rate limit normalmente (confirmado com 70 requisições reais contra o Docker de produção). Documentado em `docs/11-security.md` como um invariante a preservar.
- A estratégia de revogar toda a família de sessões ao detectar reuso de refresh token (mesmo que o reuso seja de um token revogado por logout normal, não só por roubo) é o padrão correto e deliberado da indústria (mesma abordagem usada por Auth0 e recomendada pelo OWASP para rotação de refresh token) — não é um falso positivo a "suavizar".

**Considerado e descartado** (avaliado, sem ganho técnico real o suficiente para justificar a mudança):
- Duplicação de 2 linhas ("buscar `RefreshToken` pelo hash") entre `refresh()` e `logout()` em `AuthService` — extrair um helper trocaria 2 linhas duplicadas por uma indireção; não vale a pena.
- `login()` não usa `$transaction` como `refresh()` ao criar o refresh token + atualizar `lastLoginAt` — inconsistência estilística menor; `lastLoginAt` é só informativo, sem risco de segurança se ficar dessincronizado por uma falha exatamente entre as duas escritas.

## 8. Melhorias futuras (não bloqueantes)

1. Endpoints de gestão de sessão ("ver sessões ativas", "encerrar uma sessão específica") — o schema (`RefreshToken.ipAddress/userAgent/lastUsedAt`) já suporta, faltam só os endpoints.
2. Rotação de chave JWT (`kid` no header, múltiplos segredos válidos simultaneamente) — não implementado por não ser necessário agora.
3. Rate limiting com storage compartilhado (Redis) — só relevante quando houver múltiplas réplicas do backend.
4. Atualização do NestJS v10→v11 para resolver as vulnerabilidades remanescentes em `qs`/`body-parser`/`express`.

## 9. Nota geral do Sprint

| Critério | Nota | Justificativa |
|---|---|---|
| **Arquitetura** | **9,5/10** | Isolamento por tenant com defesa em profundidade (JWT + TenantContext + extensão do Prisma), guards/decorators genéricos e reutilizáveis, escopo respeitado sem exceção. A revisão pré-`v0.2.0` (seção 7.1) removeu código morto que documentava um padrão perigoso (`set()`/`enterWith()`) e uma duplicação real de verificação de token — arquitetura mais enxuta depois da revisão do que antes. |
| **Segurança** | **9/10** | Rotação de refresh token com detecção de reuso, revogação em cascata, rate limiting confirmado via 429 real (inclusive contra requisições rejeitadas, não só bem-sucedidas), Helmet, timing-safe login, nenhum stack trace vazado. Um ponto a menos: a revisão pré-`v0.2.0` encontrou um vazamento cross-tenant real (e confirmado por teste) no `upsert` da extensão do Prisma — corrigido antes de qualquer módulo de negócio depender dele, mas é exatamente o tipo de lacuna que uma primeira passada não pegou sozinha. |
| **Cobertura de testes** | **10/10** | 87 testes (56 unit + 31 e2e), incluindo os cenários mais sensíveis (reuso de token, isolamento entre tenants em `findUnique`/`update`/`delete`/`upsert`, rate limit real, cancelamento de requisição) — sempre contra Postgres real, confirmados de forma independente em quatro momentos (local, simulação de CI, GitHub Actions real, e novamente após a revisão arquitetural). |
| **Nota geral** | **9,5/10** | Sprint entregue dentro do escopo exato pedido, com dois achados arquiteturais genuínos corrigidos durante o processo — um na implementação original (`enterWith()`), outro na revisão pré-congelamento (`upsert` sem isolamento) — ambos pegos por teste, não por inspeção visual, e ambos corrigidos antes de qualquer código de negócio depender da peça com defeito. |

---

## Conclusão

A camada de identidade do SaaSGym está pronta e testada. Nenhum módulo de negócio foi tocado, conforme pedido. A fundação para o Sprint 2 (Alunos & Professores) já inclui tudo que ele vai precisar: guards prontos para restringir por role/tenant, a extensão do Prisma pronta para filtrar automaticamente qualquer nova entidade com `academiaId`, e um padrão de módulo (`common/` vs `modules/`) já validado.
