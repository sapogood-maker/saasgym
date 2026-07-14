# Módulo 5 — Avaliação Física: análise de domínio (pré-implementação)

Escrito antes de qualquer código do Módulo 5, seguindo o mesmo fluxo usado em `docs/16`/`docs/17`/`docs/18`: analisar → propor → aprovar → só então implementar. Diferente dos módulos anteriores, este não tinha nenhuma menção prévia no roadmap (`docs/08-roadmap.md` não lista "Avaliação Física" como sprint numerada) — a única pista de escopo já existente no produto é o placeholder em `AlunoDetailScreen` ("Peso, altura, IMC, dobras e medidas ao longo do tempo", tag `MÓDULO 5 · AVALIAÇÃO FÍSICA`, corrigida na Sprint de Consolidação do Módulo 4).

## O papel da Avaliação Física no ERP

- Histórico de medidas corporais do aluno ao longo do tempo — o dado que sustenta "o aluno está evoluindo?" numa academia, e um dos poucos módulos deste ERP que não é sobre dinheiro/agenda, é sobre resultado físico.
- **Decisões de negócio já confirmadas pelo dono do produto** (nesta conversa, antes desta análise): medidas do MVP = peso + altura + IMC (calculado); qualquer usuário autenticado da academia pode registrar (sem trava de role, sem vínculo obrigatório com `Professor` — que ainda não tem login próprio); a avaliação é um **fato histórico imutável**, mesmo princípio já usado em `Aula`/`Mensalidade`/`AulaAluno.presenca`.
- **Fora do escopo deste módulo** (deliberado): percentual de gordura, dobras cutâneas, circunferências (braço/cintura/quadril/coxa), fotos de evolução, metas/objetivos, gráficos de evolução. Nenhum desses tem ainda um 2º caso de uso real que justifique o campo — mesmo critério já aplicado a `Modalidade`/`CategoriaLancamento`/`AppAutocompleteField` ao longo do projeto. Ficam registrados como extensão futura natural (o schema não precisa prever colunas pra eles agora).

## Decisões de modelo propostas

### 1. `AvaliacaoFisica` é fato histórico imutável — sem endpoint de `update`

Mesmo princípio já usado em `Aula` (MS6) e `AulaAluno.presenca` (MS8): uma vez criada, uma avaliação nunca muda peso/altura/data. Diferente de `AulaAluno.presenca` (que permite corrigir a mesma linha, porque "presença" é um estado que se corrige), aqui a correção de um erro de digitação é **soft delete + nova avaliação** — não existe operação de "editar". Isso elimina qualquer necessidade de rastrear "o que mudou" numa auditoria de update; só existem dois eventos possíveis: criada e removida (erro de cadastro).

### 2. IMC nunca é armazenado — sempre calculado

Mesmo padrão de `Mensalidade.atrasada` e `Aula` "realizada": `imc = peso / (altura/100)²` computado na resposta (DTO), nunca uma coluna no banco. Evita redundância que poderia dessincronizar se peso/altura fossem editáveis — e reforça a decisão 1 (não editáveis mesmo).

### 3. Sem vínculo com `Professor` — só `createdByUserId`

A decisão de negócio já confirmada ("qualquer usuário autenticado, sem trava de role") significa que não há necessidade de um campo `professorId`: `Professor` ainda não tem login próprio (cadastro administrativo apenas, ver `docs/14`), então "quem avaliou" já é capturado pelo mesmo `createdByUserId` que todo outro módulo do produto já usa para auditoria — sem criar uma segunda noção de autoria.

### 4. Nested sob `Aluno`, não uma coleção de topo

`AvaliacaoFisica` só faz sentido no contexto de um Aluno já aberto (não existe "lista de todas as avaliações da academia" como caso de uso pedido) — mesmo raciocínio já usado para `TurmaAluno`/`Recorrencia` (Módulo 4): entidade aninhada, rota `alunos/:alunoId/avaliacoes-fisicas`, API própria que **não estende** `CrudApi<T>` (convenção definitivamente fechada na Sprint de Consolidação, `docs/19`, seção 2 — recurso aninhado nunca estende a base genérica).

### 5. Altura em centímetros, não metros

`altura` guardada como `Decimal` em centímetros (ex. `175.5`) — mais natural pro usuário digitar («Altura: 175 cm») do que metros («1.75»). O cálculo do IMC converte internamente (`altura / 100`) na hora de computar, sem expor essa conversão em nenhum outro lugar do sistema.

## Rascunho de schema (Prisma) — para validação, não para aplicar ainda

```prisma
model AvaliacaoFisica {
  id         String   @id @default(uuid())
  academiaId String
  academia   Academia @relation(fields: [academiaId], references: [id], onDelete: Cascade)

  alunoId String
  aluno   Aluno  @relation(fields: [alunoId], references: [id])

  data        DateTime
  peso        Decimal @db.Decimal(5, 2) // kg
  altura      Decimal @db.Decimal(5, 2) // cm
  observacoes String?

  createdByUserId String
  createdBy       User   @relation(fields: [createdByUserId], references: [id])

  deletedAt DateTime? // reservado a correção de erro de cadastro — nunca "editar" (decisão 1)

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([academiaId, alunoId])
  @@map("avaliacoes_fisicas")
}
```

Novo `AuditAction`: `AVALIACAO_FISICA_CREATED`, `AVALIACAO_FISICA_DELETED` (mesmo padrão de nomenclatura `ENTIDADE_ACAO` já usado em todo o projeto).

`Aluno` ganha a relação inversa `avaliacoesFisicas AvaliacaoFisica[]`.

## Escopo proposto

**Backend**:
- `POST alunos/:alunoId/avaliacoes-fisicas` — criar.
- `GET alunos/:alunoId/avaliacoes-fisicas` — listar (paginado, ordenado por `data desc`).
- `DELETE alunos/:alunoId/avaliacoes-fisicas/:id` — soft delete (erro de cadastro).
- Sem `PATCH`/`update` (decisão 1) e sem `GET :id` isolado (a lista já traz tudo que a tela precisa — mesmo critério de simplicidade já usado quando um endpoint não tem consumidor real).
- Auditoria nas duas mutações, com `ipAddress`/`userAgent` (padrão já uniformizado em toda a Sprint de Consolidação).
- Isolamento multi-tenant: `AvaliacaoFisica` entra em `TENANT_SCOPED_MODELS`.

**Shared Core**:
- `AvaliacaoFisica` (model), `AvaliacoesFisicasApi` (bespoke, não estende `CrudApi<T>` — decisão 4).

**Frontend**:
- **Não cria tela nova.** A seção "Avaliações" de `AlunoDetailScreen` (hoje `EmptyState.comingSoon`) vira uma seção embutida real (`_AvaliacoesFisicasSection`), mesmo padrão já usado 3x no Módulo 4 (`_RecorrenciasSection`/`_AlunosMatriculadosSection`/`_AulasSection` em `TurmaDetailScreen`) — lista histórica (data, peso, altura, IMC calculado no frontend) + botão "Nova avaliação" que abre um diálogo de criação (`_NovaAvaliacaoFisicaDialog`, formulário único: data/peso/altura/observações) + ação de remover (soft delete, com `AppConfirmDialog`). Nenhum componente novo do Design System.

**Fora de escopo** (ver seção "papel no ERP" acima): % de gordura, dobras cutâneas, circunferências, fotos, metas, gráficos de evolução.

## Plano de micro-sprints (proposto)

- **MS1 — Backend**: schema + migration, `AvaliacaoFisicaService`/`Controller`, DTOs, auditoria, testes e2e (criar, listar paginado/ordenado, soft delete, bloqueio de acesso cross-tenant, 404 de aluno inexistente).
- **MS2 — Shared Core**: model + `AvaliacoesFisicasApi` + provider.
- **MS3 — Frontend**: `_AvaliacoesFisicasSection` em `AlunoDetailScreen` + diálogo de criação + remoção, validação manual via Playwright, galeria de screenshots.

Cada MS: `flutter analyze` limpo, testes completos, documentação atualizada, validação manual — mesmo padrão de todos os módulos anteriores.

## Histórico

- **2026-07-14, MS1 (Backend)**: `AvaliacaoFisica` implementada exatamente como desenhada nas decisões 1-5 acima. Migration `20260714115055_modulo5_avaliacao_fisica` (novo model + `AuditAction.AVALIACAO_FISICA_CREATED`/`AVALIACAO_FISICA_DELETED`). `AvaliacaoFisica` entrou em `TENANT_SCOPED_MODELS`. Módulo `avaliacoes-fisicas` (fora da pasta `agenda/`, já que não é Agenda — é seu próprio módulo de topo, registrado em `AppModule`): `AvaliacoesFisicasController` (`alunos/:alunoId/avaliacoes-fisicas`, sem `PATCH` — decisão 1 confirmada em código, uma tentativa de editar cai no 404 padrão de rota inexistente do Nest), `AvaliacoesFisicasService` (`create`/`list`/`remove`, sem `update`), `calcularImc` extraído em `avaliacoes-fisicas.util.ts` (testado isoladamente, 3 casos incluindo altura baixa pra garantir que a conversão cm→m não quebra). `@Roles(ACADEMIA_ADMIN, RECEPCIONISTA, PROFESSOR)` nos 3 endpoints — mesma decisão de negócio ("sem trava de role específica") aplicada literalmente ao guard, diferente do padrão usual do projeto (escrita restrita a ADMIN/RECEPCIONISTA, leitura liberada pra PROFESSOR); `ALUNO` continua bloqueado (403) — portal do aluno é módulo futuro. 11 testes e2e novos (CRUD, Professor registrando, ausência de rota de edição, invariante de não tocar `Aluno.updatedAt`, validação de peso/altura, 404 de aluno inexistente e de avaliação de outro aluno, isolamento de tenant, paginação/ordenação por data desc) — 126 unit + 313 e2e no total, todos verdes. Shared Core e Frontend ficam para MS2/MS3.
- **2026-07-14, MS2 (Shared Core)**: `AvaliacaoFisica` (model) + `AvaliacoesFisicasApi` (bespoke, não estende `CrudApi<T>` — decisão 4 confirmada em código) + `avaliacoesFisicasApiProvider`, exportados no barrel. `imc` chega pronto do backend (nunca calculado no frontend) — mesmo princípio de nunca duplicar uma regra de cálculo em duas camadas. `create`/`list`/`remove` — sem `update`, mesma ausência já confirmada no MS1. `flutter analyze` limpo em `shared_core` e `admin_web` (dependente), 27 testes de `shared_core` + 12 de `admin_web` inalterados e verdes.
- **2026-07-14, MS3 (Frontend) — Módulo 5 completo**: a seção "Avaliações" de `AlunoDetailScreen`, `EmptyState.comingSoon` desde a criação da tela, virou uma seção real (`_AvaliacoesFisicasSection`) — mesmo padrão de `_AulasSection` (`TurmaDetailScreen`, Módulo 4): `AppCard` com paginação (`AppPagination`), cada linha mostra data/peso/altura/IMC + um botão de remover (não "editar" — decisão 1). `_NovaAvaliacaoFisicaDialog` é o único formulário (`AppDateField`/`AppTextField`×2/`AppTextField` multiline opcional) — mesmo chassi de `_GerarAulasDialog`. Nenhum componente novo do Design System; zero lógica de IMC no frontend (sempre o valor que já vem do backend). Validação manual via Playwright: estado vazio, criação com validação de campos obrigatórios, listagem com IMC calculado corretamente (72.5kg/178cm → 22.9), remoção (soft delete) voltando ao estado vazio, responsividade mobile — sem regressão. `flutter analyze` limpo, 126 unit + 313 e2e (backend, inalterados), 27 (`shared_core`) + 12 (`admin_web`) testes inalterados, todos verdes.

**Módulo 5 (Avaliação Física) completo — MS1 a MS3 entregues**, sem nenhuma Sprint de Consolidação pendente (módulo pequeno o bastante para não precisar de uma própria — critério a reavaliar quando o próximo módulo também for pequeno).
