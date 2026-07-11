# Design System e padrão de CRUD (frontend)

Escrito na Sprint de Consolidação entre a Sprint 2 (módulo de Alunos) e a Sprint 3 (Professores) do frontend `admin_web`. Documenta o que ficou implícito no código durante as Sprints 1-2: a identidade visual e o padrão arquitetural que **todo módulo CRUD futuro** (Professores, Turmas, Planos, Matrículas, Avaliações, Financeiro) deve seguir, reaproveitando a infraestrutura em vez de recriá-la.

## Onde vive

Todo o Design System mora em `packages/shared_core/lib/src/design_system/` — nunca em `admin_web` ou `student_web` diretamente, porque os dois frontends compartilham a mesma identidade visual. Ponto único de import: `package:shared_core/shared_core.dart` (o barrel `design_system.dart` é reexportado por ele). Nunca importar um arquivo de token/widget do Design System por caminho direto.

```
design_system/
  tokens/      app_colors, app_typography, app_spacing, app_radius,
               app_shadows, app_motion, app_breakpoints, app_icons
  theme/       app_theme (AppTheme.darkPremium()), design_system_context
               (context.colors, context.isMobile/isTablet/isDesktop)
  widgets/
    buttons/   surfaces/   feedback/   data/   inputs/   layout/
    navigation/  overlays/
```

## Princípios (não renegociar sem decisão explícita)

- **Cor por papel, nunca por valor.** `AppColorScheme` é um `ThemeExtension`, não `static const` — isso é o que permite, no futuro, tema por academia (multi-tenant) sem reescrever nenhuma tela. Nunca `Color(0xFF...)` inline numa tela de feature.
- **Ícones exclusivamente `lucide_icons_flutter`**, mapeados por nome semântico em `AppIcons` (ex.: `AppIcons.edit`, não `LucideIcons.pencil` direto na tela). Nunca `Icons.*` (Material) numa tela nova.
- **Dark mode único** — não existe light theme nesta fase do produto.
- **Componente nasce de necessidade real.** Nenhum componente é criado "porque vai precisar" — só quando uma tela real precisa dele. Isso manteve o catálogo enxuto nas Sprints 1-2 (ver histórico abaixo).
- **Todo componente novo entra na Component Gallery** (`/design-system`, `admin_web/lib/features/design_system_gallery/`) antes de ser considerado pronto — variações, estados, e uma descrição curta do propósito. Isso é parte da definição de "pronto", no mesmo nível de "compila" e "testes verdes". A Gallery é a documentação viva do Design System — este arquivo documenta a *arquitetura*, a Gallery documenta o *catálogo visual*.

## Catálogo de componentes (por categoria da Gallery)

| Categoria | Componentes | Propósito |
|---|---|---|
| Buttons | `AppButton` | Único botão do produto — 6 variantes, loading/disabled, ícone opcional |
| Cards | `AppCard`, `MetricCard` | Superfície de conteúdo genérica; indicador/KPI (Dashboard hoje, Financeiro/Relatórios depois) |
| Lists | `AppListToolbar`, `AppListTile`, `AppDetailRow` | Barra de lista (busca+filtros+ação primária), item de lista, par rótulo/valor somente leitura (painéis de detalhe) |
| Chips | `AppBadge` | Status e contadores curtos — tom semântico nunca substitui a cor de marca |
| Empty States | `EmptyState`, `EmptyState.comingSoon` | Vazio acionável; placeholder de funcionalidade futura com a tag da sprint responsável |
| Skeleton | `LoadingSkeleton` | Placeholder de carregamento com shimmer, respeita `MediaQuery.disableAnimations` |
| Inputs | `AppTextField`, `AppSelect`, `AppDateField`, `AppAvatarPicker` | Campos de formulário — mesmo chassi de validação (`_AppFieldChrome`, privado); nenhum sabe de regra de domínio |
| Forms | `AppFormRow`, `AppFormErrorBanner` | Grid responsivo de campos (2 colunas desktop / 1 mobile); erro de formulário (nunca `SnackBar`) |
| Dialogs | `AppConfirmDialog` | Único diálogo de decisão do produto — 5 variantes de tom (`confirm`/`danger`/`warning`/`success`/`error`) |
| Navigation | `AppBreadcrumb`, `AppHeader`, `AppSidebar`, `AppPagination` | Navegação do shell; paginação server-side (`page`/`total`/`pageSize`, nunca lista client-side) |
| Motion | `AppMotion` | Durações (`fast`=120ms, `base`=180ms, `slow`=280ms) e curva padrão de toda transição |

## O padrão de CRUD (definido pela Sprint 2, módulo de Alunos)

A partir da Sprint 2, **Alunos é a referência oficial** para todo CRUD futuro. Nenhum módulo novo deve reinventar layout — deve reutilizar esta infraestrutura.

### Lista

`AppListToolbar` (busca com debounce de 400ms + filtro de status + ação primária "Novo X") → itens via `AppListTile` → `AppPagination`. 5 estados obrigatórios: carregando (skeleton com a mesma forma dos itens reais), erro, vazio sem filtro, vazio com filtro ativo (mensagem diferente), populado. Nunca tela quebrada.

Referência: `admin_web/lib/features/alunos/alunos_screen.dart`.

### Formulário

Seções em `AppCard` — no mínimo: Dados pessoais/principais, Contato (se aplicável), Endereço (se aplicável), Observações, Ações. Campos em `AppFormRow` (2 colunas desktop, empilha no mobile). Validação de campo **sempre** o chassi do MS1 (borda vermelha + mensagem abaixo do campo + ícone — nunca `SnackBar` para erro de campo). Erro de salvar sempre em `AppFormErrorBanner`. Botão salvar com 4 estados visíveis: Salvar / Salvando.../ Sucesso / Erro.

Referência: `admin_web/lib/features/alunos/aluno_form_screen.dart`.

### Detalhe (painel)

Cabeçalho: avatar somente-leitura (`AppAvatarPicker(enabled: false)`), nome, `AppBadge` de status, ações (Editar/Ativar-Inativar/Remover) via `AppButton`. Confirmação de remoção sempre via `AppConfirmDialog.show(variant: danger)` — nunca `AlertDialog` cru. Seções reais usam `AppDetailRow` dentro de `AppFormRow` (o grid de leitura rima visualmente com o grid do formulário de edição da mesma entidade). Seções de funcionalidade ainda não implementada usam `EmptyState.comingSoon` com a tag da sprint responsável do roadmap (`docs/08-roadmap.md`) — nunca dado inventado; se a sprint responsável ainda não tem número definido, usar `"EM BREVE"` em vez de chutar um número.

Cabeçalho responsivo via `context.isMobile` (empilha em coluna no mobile) — **nunca** um `Row`/`Wrap` sem `Expanded`/`Flexible` ao redor de texto de tamanho variável (ver "Bug recorrente" abaixo).

Referência: `admin_web/lib/features/alunos/aluno_detail_screen.dart`.

### Roteamento

- Telas que vivem dentro do `ShellRoute` (Dashboard, listas, Perfil) **não** têm `Scaffold` próprio — herdam o do `AppShell`.
- Telas de rota cheia fora do `ShellRoute` (`/alunos/novo`, `/alunos/:id`, `/alunos/:id/editar`) **precisam** do próprio `Scaffold` — não há nenhum ancestral Material para elas. Confundir os dois casos não é pego pelo `flutter analyze` nem por smoke test isolado (que sempre embrulha tudo num `Scaffold` de teste) — só aparece testando a navegação real. Foi um bug real da Sprint 2 (MS4), corrigido e coberto por teste de integração desde então.

## Bug recorrente (documentar para não repetir)

`Row`/`Wrap` com `mainAxisSize.min` sem `Expanded`/`Flexible` ao redor de um texto de tamanho variável estoura (`RenderFlex overflowed`) assim que usado num contexto mais estreito do que o primeiro teste cobriu. Já aconteceu em `AppButton`, `AppBreadcrumb`, `AppHeader` (mobile), `MetricCard` (dentro de `Wrap`) e no cabeçalho do `AlunoDetailScreen` (mobile). Ao criar qualquer widget novo — do Design System ou de tela —, sempre testar com texto longo **e** num container estreito antes de considerar pronto.

## Débito técnico conhecido (levantado nesta Sprint de Consolidação)

### 1. `ProfessoresScreen`/`ProfessorFormScreen`/`ProfessorDetailScreen` são pré-Design-System

As três telas de Professores (`admin_web/lib/features/professores/`) foram implementadas antes da Sprint 1 (Design System) e da Sprint 2 (padrão de CRUD) — usam `Scaffold`/`TextField`/`ListTile`/`AlertDialog` crus do Material padrão, sem nenhum componente do Design System. **O backend, o cliente HTTP (`ProfessoresApi`) e o roteamento (`app_router.dart`) já estão 100% prontos e espelham exatamente Alunos** — a Sprint 3 é puramente uma reescrita de UI reaproveitando a infraestrutura, não um CRUD novo do zero. Nenhuma mudança de modelo, API ou rota é esperada.

### 2. `AlunosApi`/`ProfessoresApi` são estruturalmente idênticas

Os dois arquivos (`packages/shared_core/lib/src/{alunos,professores}/*_api.dart`) têm exatamente os mesmos 6 métodos (`list`/`get`/`create`/`update`/`updateStatus`/`remove`/`uploadFoto`) com a mesma assinatura — só o path do endpoint e o tipo do model mudam. Essa duplicação vai se repetir mais 5 vezes (Planos, Turmas, Matrículas, Avaliações, Financeiro) se não for endereçada.

**Proposta para avaliação** (não implementada — decisão de arquitetura, fica para aprovação explícita antes da Sprint 3): extrair uma classe genérica

```dart
abstract class CrudApi<T> {
  CrudApi(this._dio, {required this.resourcePath, required this.fromJson});
  final Dio _dio;
  final String resourcePath;
  final T Function(Map<String, dynamic>) fromJson;

  Future<PaginatedResult<T>> list({String? search, UserStatus? status, int page = 1, int pageSize = 20}) async { ... }
  Future<T> get(String id) async { ... }
  Future<T> create(Map<String, dynamic> dados) async { ... }
  Future<T> update(String id, Map<String, dynamic> dados) async { ... }
  Future<T> updateStatus(String id, UserStatus status, {String? motivo}) async { ... }
  Future<void> remove(String id) async { ... }
  Future<T> uploadFoto(String id, {required Uint8List bytes, required String filename}) async { ... }
}

class AlunosApi extends CrudApi<Aluno> {
  AlunosApi(Dio dio) : super(dio, resourcePath: '/alunos', fromJson: Aluno.fromJson);
}
```

Risco de não fazer: 6 módulos × ~75 linhas quase-idênticas = duplicação real de manutenção (um bug de paginação corrigido em um lugar precisa ser lembrado em 6). Risco de fazer: acopla os módulos a uma abstração comum antes de saber se todos os futuros CRUDs realmente cabem no mesmo formato (ex.: Matrículas provavelmente não é um CRUD simples — tem fluxo aluno→plano→pagamento). Recomendação: aplicar a extração **quando Planos (Sprint 4) confirmar que o padrão se repete pela 3ª vez** — duas repetições ainda são baratas de manter à mão; a terceira é o sinal real de abstração madura.

### 3. Component Gallery tinha lacunas (corrigidas nesta Sprint)

`MetricCard` estava exportado e em uso real (Dashboard) mas não aparecia na Gallery — violava a própria regra do projeto. `AppAvatarPicker` e `AppPagination` só mostravam um estado cada. Todas as seções da Gallery ganharam uma descrição de uma linha (rule nova: "todo componente deve ter uma pequena descrição e demonstrar seus estados"). Corrigido em `admin_web/lib/features/design_system_gallery/design_system_gallery_screen.dart`.

## Convenção de testes

- `flutter analyze` limpo nos 3 pacotes (`shared_core`, `admin_web`, `student_web`) antes de qualquer entrega.
- Testes de widget: smoke test por componente em `shared_core` (`design_system_smoke_test.dart`) + teste de integração de fluxo real em `admin_web` (`widget_test.dart`, navegação via `AdminApp` real, nunca componente isolado apenas).
- Scripts de screenshot são **descartáveis** — vivem em `admin_web/test/_<nome>_screenshot_test.dart`, nunca commitados, sempre apagados após a revisão visual. Fontes reais (Archivo/JetBrains Mono/Lucide) carregadas manualmente via `FontLoader` porque `flutter test` usa uma fonte de fallback (glifos em bloco) por padrão — isso é esperado só no ambiente de teste, não indica bug de produto.
- **Gotcha de `tester.runAsync`**: capturar PNG via `RenderRepaintBoundary.toImage()` num script de screenshot exige `await tester.runAsync(() async { ...toImage()... })` — sem isso, o `toImage()` é trabalho assíncrono real do engine fora do fake clock do `flutter test`; a 1ª captura funciona, mas o runner trava (sem erro, sem timeout) ao tentar avançar pro teste seguinte.

## Histórico

- **Sprint 1** (2026-07-10): fundação do Design System — tokens, tema, `AppButton`/`AppCard`/`AppBadge`/`EmptyState`/`LoadingSkeleton`/`MetricCard`/`AppListTile`, shell de navegação (`AppSidebar`/`AppHeader`/`AppBreadcrumb`), Dashboard operacional.
- **Sprint 2** (2026-07-11): módulo de Alunos como referência de CRUD — `AppTextField`/`AppSelect`/`AppDateField`, `AppAvatarPicker`, `AppConfirmDialog`, `AppPagination`, `AppListToolbar`, `AppFormRow`, `AppFormErrorBanner`, `AppDetailRow`. Lista, formulário e painel de detalhe consolidados como padrão oficial.
- **Sprint de Consolidação** (2026-07-11): este documento; correção das lacunas da Component Gallery (`MetricCard`, estados de `AppAvatarPicker`/`AppPagination`); levantamento do débito técnico de Professores e da duplicação `AlunosApi`/`ProfessoresApi`. Nenhuma funcionalidade nova.
