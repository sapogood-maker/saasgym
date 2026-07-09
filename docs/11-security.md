# Segurança

Implementado no Sprint 1, com adições no Sprint 2 (status da academia, upload de arquivos). Complementa `docs/01-arquitetura.md` (visão geral), `docs/10-auth.md` (autenticação) e `docs/13-admin-saas.md` (administração do SaaS).

## Cabeçalhos HTTP (Helmet)

`app.use(helmet())` em `backend/src/main.ts` — CSP, `X-Content-Type-Options`, `X-Frame-Options`, remove `X-Powered-By`, etc. Configuração padrão do pacote (nenhuma customização neste sprint).

## Rate limiting

`@nestjs/throttler`, dois níveis:

- **Global**: 60 requisições/minuto por IP (`ThrottlerModule.forRoot` em `app.module.ts`), aplicado via `APP_GUARD`.
- **Login**: 5 tentativas/minuto por IP (`@Throttle()` em `AuthController.login`) — mitiga força bruta de senha especificamente, já que é o alvo óbvio.

Ambos os limites sobem para 1000/min quando `NODE_ENV=test` — sem isso, os próprios testes e2e (que fazem dezenas de logins em segundos) tropeçariam no limite pensado para tráfego real. Achado real durante a implementação: o primeiro rate limit de login quebrou a suíte e2e inteira até essa correção.

**Ordem de execução importa aqui**: `ThrottlerGuard` é registrado em `AppModule` (módulo raiz) e `JwtAuthGuard` dentro de `AuthModule` (importado depois). Verificado manualmente contra o Docker de produção: `ThrottlerGuard` roda **antes** de `JwtAuthGuard` — uma rajada de requisições sem token válido contra uma rota protegida é contada pelo rate limit e recebe `429` normalmente, não só `401` infinito. Se essa ordem for invertida no futuro (ex.: registrando `JwtAuthGuard` em um módulo importado antes do `ThrottlerModule`), requisições rejeitadas por falta de autenticação passariam a não ser contadas — abrindo uma forma de martelar endpoints protegidos sem nunca ser limitado. Ao adicionar novos `APP_GUARD` globais, preserve o `ThrottlerGuard` como o primeiro da cadeia.

## Tratamento de erros

`AllExceptionsFilter` (`backend/src/common/filters/all-exceptions.filter.ts`), global via `APP_FILTER`. Formato consistente:

```json
{ "statusCode": 404, "message": "...", "error": "...", "timestamp": "...", "path": "..." }
```

Stack trace **nunca** vai para a resposta HTTP, em nenhum ambiente — só para o log do servidor (`Logger.error`). Mais simples e mais seguro que uma checagem condicional por `NODE_ENV`: uma variável mal configurada em produção não tem como vazar o stack.

## Senhas

- Hash com `bcrypt` (custo 10) — `AuthService`.
- Política mínima aplicada na troca de senha (ver `docs/10-auth.md`).
- Comparação com hash "de mentira" quando o e-mail não existe no login, para igualar o tempo de resposta e não permitir descobrir e-mails cadastrados por timing (`DUMMY_PASSWORD_HASH` em `auth.service.ts`).

## IP do cliente

`app.set('trust proxy', 1)` em `main.ts` — necessário porque o backend roda atrás do proxy reverso do Coolify (Traefik) em produção; sem isso, `req.ip` sempre seria o IP do proxy, não o do cliente, invalidando a auditoria por IP.

## CORS

Restrito a `CORS_ORIGINS` (lista explícita, sem wildcard), com `credentials: true` para o cookie de refresh funcionar entre `admin_web`/`student_web` e a API. Testado explicitamente no Sprint 0 (origem não autorizada não recebe `Access-Control-Allow-Origin`).

## Validação e sanitização

`ValidationPipe` global (`whitelist: true`, `forbidNonWhitelisted: true`, `transform: true`) — payloads com campos não declarados no DTO são rejeitados, não apenas ignorados.

## Status da academia (Sprint 2)

`AuthService.login`/`refresh` checam `academia.status` (não só `user.status`): `SUSPENSA`/`BLOQUEADA`/`CANCELADA` bloqueiam login (mesmo com credenciais corretas — a checagem roda **depois** do `bcrypt.compare`, para não introduzir um atalho de timing distinguível de "senha errada") e refresh. Ver `docs/13-admin-saas.md` para as transições de status e a revogação em cascata de sessões que acontece ao entrar num status bloqueante — mesma classe de trade-off do JWT stateless abaixo: o access token já emitido continua valendo até expirar.

## Upload de arquivos (Sprint 2)

Validação de MIME type e tamanho no `FileInterceptor` (Multer), antes de qualquer escrita em disco — ver `docs/13-admin-saas.md`. Nome físico sempre gerado (UUID), nunca o nome original do arquivo enviado pelo cliente — evita path traversal e colisão de nomes.

## Trade-offs conhecidos (documentados, não esquecidos)

- **JWT stateless**: ver `docs/10-auth.md` — um access token vazado continua válido até expirar (≤15min), mesmo após troca de senha ou a academia ser bloqueada.
- **Rate limiting em memória**: `@nestjs/throttler` guarda contadores no processo. Com múltiplas réplicas do backend (escala horizontal), cada instância teria seu próprio contador — o limite efetivo multiplicaria pelo número de réplicas. Não é um problema na escala atual (uma instância); se/quando houver múltiplas réplicas, trocar para um storage compartilhado (Redis) é a migração natural, sem mudar a API do `ThrottlerModule`.
- **Sem rotação de chave JWT**: `JWT_ACCESS_SECRET`/`JWT_REFRESH_SECRET` são segredos únicos por ambiente (validados com mínimo de 32 caracteres no boot — `env.validation.ts`). Trocar a chave hoje invalida todos os access tokens emitidos (aceitável — eles já expiram em 15min) mas é uma decisão manual, sem suporte a múltiplas chaves simultâneas (`kid` no header do JWT). Não implementado por não ser necessário agora; documentado aqui como ponto de extensão futuro caso o produto precise de rotação sem downtime.
- **Vulnerabilidades conhecidas e aceitas**: `qs`/`body-parser`/`express` (transitivas de `@nestjs/platform-express`) têm avisos moderados/altos de DoS via parsing de query string — resolver exige subir para NestJS v11 (breaking change), tratado como item futuro dedicado (ver `PRODUCTION_READINESS.md` do Sprint 0).
