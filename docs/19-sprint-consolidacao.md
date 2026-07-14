# Sprint de Consolidação (pós-Módulo 4)

Sprint sem nenhuma funcionalidade nova — revisão crítica de tudo o que foi construído entre o Sprint 0 e o Módulo 4 (Agenda, MS1-MS8). Auditoria cruzada de Backend, Shared Core, Frontend, Design System, Performance, Documentação e Débitos técnicos, seguida só das correções com benefício comprovado. Realizada em 2026-07-13.

## 1. Backend — inconsistências encontradas e corrigidas

**Corrigidas nesta sprint:**

1. **`AulasService.gerar()` sem transação** (`backend/src/modules/agenda/aulas/aulas.service.ts`) — `aula.create` + `aulaAluno.createMany` não estavam atomicamente unidos. Se o processo caísse entre os dois, a `Aula` ficava órfã de `AulaAluno` para sempre (a checagem de idempotência só olha se a `Aula` já existe, nunca recria `AulaAluno`). Corrigido com `$transaction`.
2. **`AdminAcademiaService.updateStatus()` sem transação** — `academia.update` (muda status) e `refreshToken.updateMany` (revoga sessões) eram duas escritas separadas. Uma falha entre elas deixaria a academia bloqueada com sessões de usuário ainda ativas — exatamente o cenário de segurança que o método existe para fechar. Corrigido com `$transaction`.
3. **Módulo `admin/*` sem `ipAddress`/`userAgent` na auditoria** — `AdminAcademiaService`, `AdminAcademiaConfiguracaoService`, `AcademiaProvisioningService`, `AdminPlanoSaasService` gravavam `AuditLog` sem contexto forense, diferente dos outros 7 módulos de negócio. Corrigido: `@Req()` + `requestMetadata(req)` propagados em todos os controllers/services `admin/*`.
4. **`RequestMetadata` duplicada** — `auth.service.ts` tinha sua própria cópia da interface já existente em `common/utils/request-metadata.ts`. Removida a duplicata.
5. **12 DTOs de listagem com `page`/`pageSize` idênticos** — extraído `PaginationQueryDto` (`common/dto/pagination-query.dto.ts`), único caso do backend com 12 ocorrências byte-a-byte iguais (puro mecanismo de `class-validator`, sem regra de domínio). O único endpoint com paginação maior (`ListAulasCalendarioQueryDto`, `pageSize` até 200) manteve sua própria declaração — redeclarar `pageSize` numa subclasse acumularia os decorators da base e da subclasse (`class-validator` agrega toda a cadeia de protótipos), então o `@Max(100)` continuaria valendo junto do `@Max(200)`, um resultado pior.

**Investigado e explicitamente rejeitado (não é bug):**

- Isolamento multi-tenant (`TENANT_SCOPED_MODELS`) — conferido campo a campo contra o schema; nenhum gap. `Arquivo`/`AcademiaConfiguracao` ficam fora do set de propósito (nunca listados por tenant hoje, sempre acessados por id explícito) — anotado como ponto de atenção só se ganharem endpoint de listagem/self-service no futuro.
- Cobertura de `AuditLog` — 100% das mutações de negócio já auditam; o único gap era o contexto de IP/UA do item 3 acima, agora fechado.
- `aula-alunos.controller.ts` misturar dois prefixos de recurso pai (`agenda/aulas/:aulaId/alunos` e `agenda/alunos/:alunoId/frequencia`) — justificado (é a Frequência, que de fato pertence às duas árvores); dividir em 2 controllers teria o mesmo custo sem ganho.
- Mapeamento DTO no controller em vez do service (só no grupo `admin/*`) — inconsistência real de onde a conversão mora, mas sem vazamento HTTP; não vale abrir tarefa só por isso.
- Duplicação de `findOrThrow`+`toResponse`+paginação em 8 services — cada `toResponse` tem forma de domínio própria; extrair só ganharia a "casca" e perderia legibilidade linear. Rejeitado.

## 2. Shared Core — CrudApi\<T\>, APIs, models, enums

**Débito técnico do `CrudApi<T>` encerrado.** A pergunta original ("nested resource com paginação ou `/status` ainda precisa de classe própria?") está definitivamente respondida: **sim, sempre** — `RecorrenciasApi`, `TurmaAlunosApi`, `AulasApi`, `AulaAlunosApi` são as 4 confirmações reais, independente de paginação ou rota `/status` dedicada. `MatriculasApi` é um caso diferente (entidade top-level com transições de ciclo de vida bespoke — trancar/reativar/cancelar/renovar — mas ainda estende `CrudApi<Matricula>` para `get`/`update`/`remove`); não deve ser contada junto das 4 confirmações de "recurso aninhado". Todas as 17 classes de API do produto foram reclassificadas e nenhuma delas está no lugar errado.

Models, enums (`fromJson`/`toJson`) e `PaginatedResult<T>` — 100% consistentes, sem divergência de estilo em nenhum dos 14 enums nem nas ~20 classes de model. Providers (`api_providers.dart`) — 17 providers, 1:1 com as 17 classes de API, nomeação uniforme.

**Extraído nesta sprint** (único achado real de duplicação em `shared_core`, ambos vindos de fora do pacote):
- `mensagemErroApi(DioException)` — corpo idêntico duplicado em 15 arquivos do `admin_web`. Agora vive em `src/api/dio_error_message.dart`.
- `dataCurtaFormat` — `DateFormat('dd/MM/yyyy')` cacheado, duplicado como constante de módulo em 6 telas + reconstruído inline (sem cache) em mais 2 pontos. Agora vive em `src/common/date_formats.dart`.

## 3. Frontend (admin_web) — inconsistências e correções

**Corrigidas nesta sprint:**

1. **Rotas de Aluno/Professor/Plano sem `key: ValueKey(id)`** — bug já autodiagnosticado num comentário do próprio `app_router.dart` desde o Módulo 2 (Matrícula/Turma já tinham a correção, mas o comentário dizia explicitamente "não alterado aqui... fora do escopo"). Navegar direto de um `/editar` pra outro (ids diferentes) sem desmontar a tela reaproveitava o `State` e mostrava dados do registro anterior. Corrigido nas 9 rotas de Aluno/Professor/Plano.
2. **`CalendarScreen` sem "Limpar filtros"** — única tela com filtros no produto sem essa ação (as outras 7 telas filtradas têm). Adicionado botão `ghost` "Limpar filtros" na barra de filtros, visível só quando algum filtro está ativo.
3. **`AppSelect`/`AppDateField` sem borda de foco visível** — só `AppTextField` acendia a borda no tom de marca ao ganhar foco; os outros dois campos da mesma "casca" (`AppFieldChrome`) nunca passavam `focused: true`. Extraído `AppFieldFocusTracker` (antes um `_FocusTrackingField` privado só do `AppTextField`) e reaproveitado pelos 3 campos.
4. **`AppPagination`/`AppHeader` com botões de ícone sem nome acessível** — `_StepButton` (anterior/próxima página) e `_NotificationsButton` (sino) não tinham `Tooltip`, ao contrário de todo `AppButton`/`_HeaderIconButton` irmão. Adicionado `Tooltip` nos dois.

**Investigado e explicitamente rejeitado (documentado em `docs/15`):**

- `AppCrudDialog`/`AppPromptDialog<T>` genérico — 7 consumidores reais (`_CancelarMatriculaDialog`, `_AcoesMensalidadeDialog`, `_AcoesLancamentoDialog`, `_AcoesModalidadeDialog`, `_AcoesRecorrenciaDialog`, `_AcoesTurmaAlunoDialog`, `_AulaAcoesDialog`) muito além do gatilho de "3ª ocorrência" — mas o número de views (1 a 4), os campos e o grafo de transição variam demais entre eles; um `_CancelarMatriculaDialog` nem segue o formato "menu → view". Forçar uma abstração exigiria um builder-por-view, virando indireção sem simplificação real.
- `AppEntitySelect` — o padrão "selecionar entidade via `AppSelect`" repete de fato só 1 linha (`for (...) AppSelectOption(...)`); tudo em volta (rótulo, opção sentinela "Todos"/"Usar titular", obrigatoriedade, timing do fetch) é bespoke por tela. Extrair custaria mais em parâmetros opcionais do que economizaria.
- `AppListScreen<T>` genérico — duplicação real e extensa entre as ~9 telas de lista (debounce, paginação, skeleton, toolbar), mas é replicação **intencional** de um padrão de referência desde o Sprint 3 (documentado em comentário em cada tela), não descuido. Candidato de sprint futura, não desta (mudança estrutural maior do que o escopo permite).
- Dashboard/Perfil usando `FutureProvider`+`AsyncValue` em vez do `FutureBuilder`+`setState` do resto das telas — inconsistência real mas defensável (não têm busca/paginação/filtro pra justificar estado mutável local); anotado como convenção a documentar, não a refatorar.
- `context.isMobile` — usado só nas 8 telas que constroem layout customizado de 2 colunas; toda tela de lista/formulário já herda responsividade de `AppListToolbar`/`AppFormRow`. Não é inconsistência, é o resultado esperado de um Design System bem composto.

## 4. Performance — medido, não especulado

Script de benchmark (`ts-node` + `createTestApp()`, dados descartados ao final) simulando uma academia de porte considerável:

| Operação | Volume | Tempo |
|---|---|---|
| `MensalidadesService.gerar()` (1º run) | 500 matrículas ATIVA | 2836 ms (500 criadas) |
| `MensalidadesService.gerar()` (idempotente) | 500 matrículas, todas já geradas | 606 ms |
| `AulasService.gerar()` (1º run) | 4 recorrências × 90 dias, 500 `TurmaAluno` por aula | 7528 ms (53 aulas × 500 `AulaAluno` cada) |
| `AulasService.gerar()` (idempotente) | mesmo período | 59 ms |
| `AulasService.listCalendario()` | 90 dias, 53 aulas | 31 ms |
| `DashboardFinanceiroService.resumo()` | 2234 mensalidades PENDENTE vencidas | 25 ms |

**Nenhuma otimização foi aplicada.** Nenhum dos quatro fluxos mostrou um gargalo real no volume testado (500 alunos/matrículas é uma academia de porte médio-grande hoje). O padrão N+1 dos dois geradores (`findFirst` de existência dentro do loop, sem batch) é estruturalmente o mesmo em ambos, mas só o de Mensalidades opera sobre um conjunto potencialmente ilimitado (todas as matrículas ativas da academia, sem janela) — o de Aulas é limitado pela janela de geração (dias × recorrências, tipicamente dezenas). Registrado como ponto de atenção para quando (se) uma academia Enterprise (sem `limiteAlunos`) crescer muito além deste teste — não como debt de ação imediata.

## 5. Documentação — revisão integral (docs/02, 08, 15, 16, 17, 18)

**Corrigido:**
- `docs/02-banco-de-dados.md` — a maior desatualização encontrada: a seção "Modelagem planejada" ainda listava `Turma`/`Recorrencia`/`Aula`/`TurmaAluno`/`AulaAluno` como entidades futuras, 7 micro-sprints depois de todas terem sido implementadas (só havia sido atualizada uma vez, ao final do MS1). Reescrita: as 5 entidades agora aparecem em "Implementado".
- `docs/08-roadmap.md` — linha do Sprint 4 dizia "`Modalidade` pendente" sem nunca ter sido atualizada quando `Modalidade` foi implementada no Módulo 4 MS1 (a informação correta só existia 1 linha abaixo, na linha do Sprint 5). Cross-referenciado.
- `docs/15-design-system-e-padrao-crud.md` — veredito final sobre `AppPromptDialog<T>` registrado (ver seção 3 acima), fechando um "candidato a avaliar" que vinha sendo adiado desde o Módulo 3.

**Confirmado como preciso, sem alteração:** `docs/16` (Matrículas) e `docs/17` (Financeiro) batem exatamente com o schema e o código atual. `docs/18` (Agenda) é o documento mais bem autoauditado do conjunto — já sinalizava sua própria pendência conhecida (card "Agenda do dia" do Dashboard).

## 6. Débitos técnicos — inventário e decisão individual

| # | Débito | Decisão |
|---|---|---|
| 1 | `CrudApi<T>` — nested resource nunca estende | **Encerrado.** 4 confirmações reais, convenção definitiva (seção 2). |
| 2 | `AppPromptDialog<T>` — extrair diálogo genérico | **Descartado.** 7 consumidores, mas divergência real demais (seção 3). |
| 3 | `_mensagemErro` duplicado (15×) | **Corrigido** — `mensagemErroApi` em `shared_core`. |
| 4 | `DateFormat('dd/MM/yyyy')` duplicado (6× + 2 inline) | **Corrigido** — `dataCurtaFormat` em `shared_core`. |
| 5 | Rotas sem `ValueKey(id)` (Aluno/Professor/Plano) | **Corrigido.** |
| 6 | `AulasService.gerar()` sem transação | **Corrigido.** |
| 7 | `AdminAcademiaService.updateStatus()` sem transação | **Corrigido.** |
| 8 | Auditoria do `admin/*` sem IP/UA | **Corrigido.** |
| 9 | `RequestMetadata` duplicada em `auth.service.ts` | **Corrigido.** |
| 10 | 12 DTOs de paginação idênticos | **Corrigido** — `PaginationQueryDto`. |
| 11 | `AppSelect`/`AppDateField` sem foco visível | **Corrigido** — `AppFieldFocusTracker`. |
| 12 | `AppPagination`/`AppHeader` sem `Tooltip` em botões de ícone | **Corrigido.** |
| 13 | `CalendarScreen` sem "Limpar filtros" | **Corrigido.** |
| 14 | `AppEntitySelect` — extrair seletor de entidade genérico | **Descartado** (seção 3). |
| 15 | `AppListScreen<T>` — extrair lista genérica | **Mantido para sprint futura** — real, mas fora do escopo desta (mudança estrutural maior). |
| 16 | Reposição de aula / fila de espera (`AulaAluno.tipo`) | **Mantido — fora de escopo do Módulo 4**, já documentado desde o MS1 (docs/18). Sprint 6 do roadmap. |
| 17 | `SolicitacaoAgenda` / `NotificationProvider` | **Mantido — fora de escopo**, depende do Portal do Aluno (Sprint 10). |
| 18 | Enforcement de limites de `PlanoSaas` | **Mantido — fora de escopo**, aguarda módulos com dado suficiente (roadmap já cita isso). |
| 19 | Seções `EmptyState.comingSoon` cujo módulo já foi entregue (Matrículas/Financeiro/Frequência nos painéis de Aluno/Professor/Plano; "Alertas"/"Ações pendentes" no Dashboard) | **Não corrigido nesta sprint** — wiring de dado real é funcionalidade nova, fora do escopo de uma sprint de consolidação. Registrado como backlog de baixo risco (APIs já existem) para o Sprint 8 do roadmap ("Dashboard da academia — expansão") ou equivalente. |
| 20 | `sprintTag` com numeração "SPRINT N" pré-reorganização (`SPRINT 6/7/8`) | **Corrigido** as 6 ocorrências de `SPRINT 6 · FINANCEIRO` → `MÓDULO 3 · FINANCEIRO`; `SPRINT 7 · AVALIAÇÃO FÍSICA` → `MÓDULO 5 · AVALIAÇÃO FÍSICA` (nome do próximo módulo, já decidido); `SPRINT 8 · TREINOS` → `EM BREVE` (sem número de módulo confirmado ainda). |
| 21 | 4 testes do `widget_test.dart` do `admin_web` quebrados por drift (labels antigos, sidebar cresceu além da viewport de teste, "Mensal" virou ambíguo com "Mensalidades" da sidebar) | **Corrigido** — os 4 testes atualizados para refletir o estado atual da UI. |
| 22 | `AppDialogChrome` — extrair só o wrapper visual do diálogo (~70 linhas idênticas em 7 arquivos, puro markup) | **Não extraído nesta sprint** — candidato válido e de baixíssimo risco, registrado em `docs/15` como próxima oportunidade, não como pendência aberta. |

## 7. Testes — suíte completa

- Backend: **123 unit + 302 e2e**, todos verdes (rodados antes e depois de cada correção).
- Shared Core: **27 testes** (`design_system_smoke_test.dart`), verdes.
- Admin Web: **12 testes** (`widget_test.dart`) — 4 estavam quebrados por drift de texto (não por regressão desta sprint), corrigidos; `flutter analyze` limpo.
- Student Web: **1 teste** (placeholder da tela inicial), verde; `flutter analyze` limpo. Confirmado que `student_web` continua sendo só o esqueleto do Sprint 0 (login estático, sem integração com API) — consistente com o roadmap (Sprint 10, "Planejado").

Achado à parte, fora do escopo de código: a suíte e2e do backend é **flaky sob paralelismo default do Jest** neste ambiente (25 suítes rodando em paralelo esgotam conexões/CPU e um `beforeAll` estoura o timeout de 5s) — rodando `--runInBand` (serial) os 302 testes passam de forma consistente em ~73-79s. Não alterado (config de CI já roda em runner dedicado, achado registrado para referência, não uma mudança de configuração feita nesta sprint).

## 8. Saúde geral da arquitetura

- **Multi-tenant**: sem gaps de isolamento. Padrão `forTenant()` + `TENANT_SCOPED_MODELS` aplicado consistentemente em 100% dos acessos a dado tenant-scoped.
- **Auditoria**: 100% de cobertura em mutações, agora com contexto forense (IP/UA) uniforme em todos os módulos, incluindo Admin.
- **CrudApi\<T\>**: convenção madura e definitivamente resolvida — 17 classes de API, cada uma no lugar certo.
- **Design System**: reaproveitado com disciplina real em 4 módulos e 8 micro-sprints só da Agenda; as duas únicas inconsistências de acessibilidade encontradas (foco visível, `Tooltip` em botões de ícone) eram gaps pontuais, não sistêmicos, e já foram fechadas.
- **Documentação**: estava, em geral, muito bem mantida (docs/15-18 quase sempre atualizados no mesmo commit da funcionalidade); o único desvio grande (docs/02) era um esquecimento pontual, não um padrão de negligência — corrigido.
- **Performance**: nenhum gargalo real medido em volume acima do uso típico atual.

## 9. Recomendação: iniciar o Módulo 5 (Avaliação Física)?

**Sim, o projeto está pronto.** Não há nenhum bug de correção de dados, nenhuma falha de isolamento multi-tenant, nenhum teste vermelho, e nenhuma dívida técnica crítica pendente de decisão — todas as 22 identificadas nesta sprint foram corrigidas, descartadas com justificativa registrada, ou conscientemente adiadas para um sprint futuro já previsto no roadmap (não "esquecidas"). As duas únicas correções de maior risco potencial (transações em `AulasService.gerar()` e `AdminAcademiaService.updateStatus()`) foram aplicadas e validadas pela suíte e2e completa sem quebrar nada.

O único item que vale nomear explicitamente antes de seguir: os placeholders de `EmptyState.comingSoon` cujo módulo real já existe (Matrículas/Financeiro/Frequência nos painéis de Aluno/Professor, "Alertas importantes"/"Ações pendentes" no Dashboard) não são um risco técnico — são um backlog de baixíssimo esforço (as APIs já existem, é só wiring) que fica mais barato de fazer mais cedo que mais tarde, mas que não bloqueia o Módulo 5 de forma alguma.
