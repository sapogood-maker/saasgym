# SaaSGym — Relatório Final do Sprint 2 (Administração do SaaS)

**Data:** 2026-07-09
**Escopo:** infraestrutura administrativa do próprio SaaS — cadastro/ciclo de vida de academias, configuração/branding, catálogo de planos comerciais (sem cobrança), storage desacoplado (primeiro uso real), dashboard do `SYSTEM_ADMIN`. Nenhum módulo de negócio da academia (Alunos, Agenda, Financeiro etc.).
**Commits:** `6849288` (implementação) + `272a8c8` (correção de flakiness em testes) — CI verde no GitHub Actions em ambos.

---

## 1. Arquitetura implementada

```
backend/src/
├── storage/                    StorageProvider (interface) + LocalDiskStorageProvider +
│                                FileUploadService — genérico, reaproveitável por
│                                qualquer módulo futuro com upload
├── common/academia/             isAcademiaStatusBlocking() — compartilhado entre
│                                AdminAcademiaService e AuthService
└── modules/admin/
    ├── academias/               AcademiaProvisioningService (criação transacional),
    │                            AdminAcademiaService (CRUD/status),
    │                            AdminAcademiaConfiguracaoService (branding)
    ├── planos-saas/              catálogo comercial do SaaS
    └── dashboard/                agregados do SYSTEM_ADMIN
```

**Decisões arquiteturais e por quê** (validadas com o usuário antes de codar):

- **Inversão da ordem do roadmap**: o plano do Sprint 0 colocava Alunos & Professores logo após a autenticação; o usuário decidiu explicitamente que o SaaS precisava da própria infraestrutura administrativa antes de qualquer módulo de negócio — sem isso, uma academia só existiria via seed manual, sem ciclo de vida real.
- **Storage local nesta sprint, arquitetura pronta para trocar** — `STORAGE_PROVIDER` (env var) escolhe a implementação em runtime; `local` é a única que existe, mas `r2`/`s3`/`google-drive`/`minio`/`backblaze` já são valores válidos na validação de ambiente (selecioná-los falha alto e claro no boot). Nenhum módulo de negócio importa `LocalDiskStorageProvider` diretamente — só a interface via `FileUploadService`.
- **Criação de academia como transação única + evento de domínio pós-commit**: `AcademiaProvisioningService` cria `Academia`+`User`(admin)+`AcademiaConfiguracao` numa `$transaction` (tudo ou nada); auditoria é uma chamada direta e garantida depois do commit; um evento `academia.provisionada` (via `@nestjs/event-emitter`) é o ponto de extensão para passos futuros (e-mail de boas-vindas etc.) — sem nenhum listener hoje, um no-op real, não um stub fingindo funcionalidade.
- **`PlanoSaas` como nome deliberado**, não `Plano` — evita colisão permanente com o `Plano` de negócio (mensalidade que a academia vende ao aluno), que chega num sprint futuro.
- **Model `Arquivo` genérico** desde já, não uma coluna `logoUrl` solta — qualquer upload futuro (foto de aluno/professor, mídia de exercício) reaproveita a mesma tabela de metadados sem nova modelagem.

## 2. Endpoints criados

Todos em `/api/admin`, 100% restritos a `SYSTEM_ADMIN` (`SystemAdminGuard`).

| Endpoint | Descrição |
|---|---|
| `POST /admin/academias` | Cria academia + admin inicial + configuração, transacional |
| `GET /admin/academias` | Lista paginada, filtro por status |
| `GET /admin/academias/:id` | Detalhe |
| `PATCH /admin/academias/:id` | Edição cadastral |
| `PATCH /admin/academias/:id/status` | Transição de status + revogação em cascata |
| `GET`/`PUT /admin/academias/:id/configuracao` | Branding |
| `POST /admin/academias/:id/logo` | Upload de logotipo |
| `GET`/`POST`/`PATCH /admin/planos-saas` | Catálogo de planos (sem delete) |
| `GET /admin/dashboard` | Agregados da plataforma |

## 3. Fluxo

Ver `docs/13-admin-saas.md` para o documento completo. Resumo: `SYSTEM_ADMIN` cria uma academia → transação cria academia (status `TRIAL`) + primeiro `ACADEMIA_ADMIN` + configuração vazia → auditoria + evento de domínio pós-commit → o admin criado já consegue logar imediatamente. Transições de status para `SUSPENSA`/`BLOQUEADA`/`CANCELADA` revogam em cascata todas as sessões ativas da academia e passam a bloquear login/refresh (`AuthService`, ver `docs/11-security.md`).

## 4. Cobertura de testes

**93 testes** — 81 unitários (12 novos/ajustados no Sprint 2) + 81 e2e (reais, contra Postgres, confirmados em múltiplas execuções consecutivas sem flakiness).

| Camada | O que cobre |
|---|---|
| `LocalDiskStorageProvider` (unit) | Nome físico sempre UUID, organização por categoria, `delete` idempotente |
| `FileUploadService` (unit) | Combina provider + metadados, `delete` remove provider e registro |
| `AcademiaProvisioningService` (unit) | Transação, resolução do plano padrão, senha nunca em texto puro, auditoria/evento só depois do commit, nada acontece se a transação falhar |
| `isAcademiaStatusBlocking` (unit) | Os 5 status, mapeados corretamente |
| `academia-provisioning.e2e-spec.ts` | Rollback real (e-mail duplicado não deixa academia parcial), login imediato após provisionamento, auditoria com `academiaId` correto |
| `admin-academias.e2e-spec.ts` | CRUD completo, 401/403/404/400, revogação em cascata de sessão real ao suspender, isolamento entre academias, upload real com comparação binária byte-a-byte, substituição de logo sem órfãos |
| `academia-status-enforcement.e2e-spec.ts` | Os 3 status bloqueantes rejeitando login com credenciais corretas, auditoria do motivo, bloqueio de refresh de sessão que ficou órfã depois do login |
| `admin-planos-saas.e2e-spec.ts` | CRUD, nome duplicado → 409, "remoção" via `ativo:false` |
| `admin-dashboard.e2e-spec.ts` | Agregados reais, 401/403 |

## 5. Riscos encontrados e corrigidos durante a implementação

| # | Achado | Como foi pego | Correção |
|---|---|---|---|
| 1 | `@ValidateNested()` sozinho não torna um campo obrigatório — `adminInicial` ausente no payload de criação de academia passava como `undefined` e quebrava com 500 em vez de 400 | Teste e2e | `@IsNotEmptyObject()` antes de `@ValidateNested()` |
| 2 | Teste de cascata de revogação testava o token errado — fazia um novo login *depois* de suspender a academia (ainda não bloqueado, é a Etapa 6) e verificava esse token, não o que estava ativo no momento da suspensão | Teste falhou de forma reveladora (esperado 401, veio 200) | Corrigida a lógica do teste: login → suspender → verificar o token que já estava ativo |
| 3 | **Volume Docker de uploads criado como `root`, container roda como usuário `node` (não-root)** — todo upload falhava com `EACCES: permission denied, mkdir '/app/uploads/academias'` | Validação manual contra Docker real (não pega em teste unitário/e2e, que não usa o Dockerfile de produção) | Dockerfile pré-cria `/app/uploads` com `chown node:node` antes do volume ser montado — um volume nomeado novo herda permissão do diretório da imagem na primeira inicialização. Documentado em `docs/13-admin-saas.md` e no checklist do Coolify (`docs/09-checklist-deploy-coolify.md`), já que o mesmo problema aconteceria em produção |
| 4 | **Teste de dashboard comparava delta exato de contagem global (antes/depois) — racy sob execução paralela**: Jest roda arquivos de e2e em workers paralelos contra o mesmo Postgres; outro arquivo criando uma academia na mesma janela quebrava a asserção | Falha intermitente real ao rodar a suíte repetidamente (não hipotética — reproduzida) | Asserção trocada de igualdade exata para `>=` sobre o efeito da própria escrita, que nenhum outro worker pode invalidar |
| 5 | **Fixture de teste gerava nomes/CNPJs únicos só com `Date.now()`** — colidiu de verdade entre processos (workers) diferentes na mesma millisecond, sob carga de 8 arquivos e2e em paralelo | Falha intermitente real (`Unique constraint failed`), reproduzida ao repetir a suíte | Trocado para UUID (`crypto.randomUUID()`) em `test/utils/fixtures.ts` — sem coordenação entre workers necessária |

Os itens 3-5 só apareceram com verificação de verdade (Docker real, execução repetida da suíte) — nenhum deles seria pego por uma única rodada de testes ou por revisão estática de código, reforçando o valor da disciplina de "rodar de verdade, mais de uma vez" já estabelecida desde o Sprint 0.

## 6. Avaliação de segurança

- Todo endpoint administrativo exige `SystemAdminGuard` — confirmado via e2e real (403 para `ACADEMIA_ADMIN`) em cada recurso.
- Upload validado por MIME type e tamanho (2MB) antes de qualquer escrita em disco; nome físico sempre UUID, nunca o nome enviado pelo cliente — evita path traversal e colisão.
- Status da academia aplicado tanto em login (checagem depois do `bcrypt.compare`, sem introduzir atalho de timing) quanto em refresh, com revogação em cascata das sessões ativas ao entrar num status bloqueante.
- Toda mutação administrativa é auditada com o autor real (`SYSTEM_ADMIN` do `TenantContext`), nunca inferido.
- Nenhum dado fictício no dashboard — backups reportados como indisponíveis (módulo não existe), não um número inventado para preencher a tela.

## 7. Avaliação de arquitetura

- `StorageProvider`/`FileUploadService` genéricos desde a primeira implementação — a extensão para novos uploads (aluno, professor, exercício) nos próximos sprints não deve exigir nenhuma mudança na infraestrutura, só um novo método por caso de uso.
- Separação limpa entre `AcademiaProvisioningService` (orquestração transacional, caso de uso complexo) e `AdminAcademiaService`/`AdminAcademiaConfiguracaoService` (CRUD simples) — evita um único service acumulando responsabilidades desproporcionais.
- `isAcademiaStatusBlocking` compartilhado entre o módulo admin (que decide a transição) e `AuthService` (que aplica a consequência) — uma única fonte da verdade sobre quais status bloqueiam acesso.
- Nomenclatura pensada para o futuro: `PlanoSaas` nunca vai colidir com o `Plano` de negócio; `Arquivo` já nasce genérico em vez de uma coluna `logoUrl` que precisaria ser refeita no primeiro upload de um tipo diferente.

## 8. Melhorias futuras (não bloqueantes)

1. Enforcement dos limites de `PlanoSaas` (`limiteAlunos`, `limiteProfessores` etc.) — estrutura pronta, sem nada para comparar ainda (aguarda `Aluno`/`Professor`).
2. Provider de storage em produção (R2/S3) — `LocalDiskStorageProvider` é adequado para uma única instância; migrar antes de qualquer plano de escala horizontal do backend.
3. Listener real para o evento `academia.provisionada` (e-mail de boas-vindas) — o ponto de extensão já existe, só falta o consumidor.
4. Endpoint de "gestão de sessão" já mencionado no Sprint 1 continua pendente — agora com mais urgência prática, já que o `SYSTEM_ADMIN` revoga sessões em massa mas não tem visibilidade individual delas.

## 9. Nota geral do Sprint

| Critério | Nota | Justificativa |
|---|---|---|
| **Arquitetura** | **9,5/10** | Storage genérico desde o primeiro uso, transação + evento de domínio bem separados (dados críticos vs. extensão futura), nomenclatura pensada para não colidir com módulos ainda não construídos. |
| **Segurança** | **9,5/10** | Todo endpoint administrativo comprovadamente restrito a `SYSTEM_ADMIN`, validação de upload real, status da academia aplicado sem introduzir side-channel de timing, revogação em cascata funcionando de ponta a ponta. |
| **Cobertura de testes** | **9,5/10** | 93 testes, incluindo os cenários mais sensíveis (rollback transacional, revogação em cascata, upload binário real com verificação byte-a-byte) — mas dois deles eram flaky sob paralelismo até serem corrigidos nesta própria sprint; meio ponto a menos por não terem nascido corretos, ainda que corrigidos e reverificados com múltiplas execuções antes do fechamento. |
| **Nota geral** | **9,5/10** | Sprint entregue dentro do escopo exato pedido, com um bug de produção real (`EACCES` no volume) e dois bugs de teste reais (flakiness sob paralelismo) encontrados e corrigidos por verificação de verdade — Docker real e execução repetida da suíte — antes de fechar, não por sorte. |

---

## Conclusão

A infraestrutura administrativa do SaaS está pronta e testada. `SYSTEM_ADMIN` consegue criar, configurar, suspender/bloquear/cancelar academias e enxergar a plataforma inteira, tudo de ponta a ponta contra Docker real. O roadmap foi reescrito para refletir essa fundação: os módulos de negócio (Sprint 3 em diante) agora nascem sobre uma base onde toda academia tem plano, configuração e um admin funcional desde a criação — não mais dependente de seed manual.
