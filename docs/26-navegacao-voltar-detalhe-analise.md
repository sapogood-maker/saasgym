# Navegação "Voltar" nas telas de detalhe — Análise de domínio e UX

## O problema

Toda tela de detalhe/formulário (`/alunos/:id`, `/agenda/turmas/:id/editar` etc.) vive **fora** do `ShellRoute` (`admin_web/lib/routing/app_router.dart`) — de propósito, para ganhar tela cheia sem sidebar/topbar. Consequência colateral: nenhuma dessas telas tem sidebar, `AppHeader` ou `AppBreadcrumb` — o único jeito de "voltar" é o botão do navegador. Em PWA/desktop instalado (sem chrome de navegador visível) isso não existe, e mesmo na aba do navegador é um padrão de navegação implícito, não uma affordance visível na própria tela.

## O que já existe (levantamento factual, nada implementado ainda)

Levantamento completo de `admin_web/lib/features/**` e `app_router.dart`:

**Telas de detalhe** (`Scaffold` próprio, fora do Shell, com `PopScope(canPop: false, ...)` interceptando o pop do sistema pra devolver um `bool` de "mudou algo" pro chamador):
- `AlunoDetailScreen` (`/alunos/:id`)
- `ProfessorDetailScreen` (`/professores/:id`)
- `TurmaDetailScreen` (`/agenda/turmas/:id`)
- `PlanoDetailScreen` (`/planos/:id`)
- `MatriculaDetailScreen` (`/matriculas/:id`)

**Telas de formulário** (mesmo `Scaffold` fora do Shell, mas **sem** `PopScope` — `Cancelar`/`Salvar` já chamam `context.pop(bool)` diretamente):
- `AlunoFormScreen` (`/alunos/novo`, `/alunos/:id/editar`)
- `ProfessorFormScreen`, `TurmaFormScreen`, `PlanoFormScreen`, `MatriculaFormScreen` (mesmo par novo/editar)

**Todas as 5 entidades de detalhe seguem o mesmo padrão de navegação**, sem exceção:
1. A lista (`AlunosScreen` etc.) abre o detalhe com `await context.push<bool>('/alunos/${aluno.id}')`.
2. O estado da lista (`_search`, `_statusFiltro`, `_pagina`, scroll) vive no `State` da própria tela de lista — **nunca é serializado em rota/query param**.
3. Como `push()` empilha a rota nova sem descartar a de baixo, esse `State` da lista continua vivo (só pausado) enquanto o usuário está no detalhe.
4. Voltar hoje (botão do navegador → gesto de sistema → `PopScope`) sempre termina em `context.pop(_alterado)`, devolvendo o controle pra exata mesma instância de `AlunosScreen` — sem refetch, sem perda de filtro/página, a não ser que `_alterado == true` (aí a lista se recarrega de propósito, pra refletir a mudança).

**Isso já resolve o requisito 5 (preservar filtro/busca/paginação) para o caminho normal** — o problema não é perda de estado, é a *ausência de uma affordance visível* pro mesmo mecanismo que já funciona.

### Casos fora do padrão — não são "tela de detalhe roteada"

- **Mensalidade**: não existe rota `/financeiro/mensalidades/:id`. As ações (marcar paga, editar) abrem um **diálogo** (`_AcoesMensalidadeDialog`, dentro de `mensalidades_screen.dart`) por cima da própria lista — a lista nunca é substituída, então o problema de "sem botão de voltar" não existe aí (fechar o diálogo já volta pro mesmo estado, sem navegação de rota nenhuma).
- **Aula** (Calendário): mesmo caso — `_abrirAcoes(Aula)` em `calendar_screen.dart` abre diálogo, não rota.
- **Lançamento** (Caixa), **Modalidade**, **Solicitação de reposição**: idem, tudo diálogo sobre a própria lista.

> O pedido original cita "Mensalidade Julho/2026" como exemplo do padrão de texto — mas hoje não existe uma tela de Mensalidade pra aplicar o header nela. Confirmado (2026-07-15): fica de fora desta sprint.

## Proposta de UX

Um cabeçalho de duas linhas, no topo do corpo da tela (antes de qualquer `AppCard`):

```
←  Alunos
   Paulo Sergio de Lima                    [Editar] [Inativar] [Remover]
```

- Linha 1: seta + nome da lista de origem, tom discreto (`colors.textMuted`, hover pra `colors.text`) — link clicável, não um `AppButton` (é wayfinding, não uma ação primária da tela).
- Linha 2: o bloco que já existe hoje em cada tela (avatar opcional + título + badge de status) + a fileira de ações (`Editar`/`Inativar`/`Remover`/...), lado a lado no desktop e empilhado no mobile — **exatamente a mesma composição de hoje**, só que agora dentro do componente novo em vez de solta no `Column` da tela.

**Decisão de texto** (confirmada 2026-07-15): `← Alunos` (só o rótulo da lista) — mais curto, e é o padrão já usado em back-links de app (iOS, Linear, Notion: nome da tela anterior, sem "Voltar para" redundante com a própria seta).

## Arquitetura proposta

### Componente único: `AppDetailHeader` (Design System, `shared_core`)

Mesmo diretório de `AppBreadcrumb` (`packages/shared_core/lib/src/design_system/widgets/navigation/app_detail_header.dart`), exportado em `design_system.dart`/`shared_core.dart` — reutilizável por qualquer tela futura (student_web incluso, se um dia tiver telas de detalhe).

```dart
class AppDetailHeader extends StatelessWidget {
  const AppDetailHeader({
    required this.listLabel,
    required this.onBack,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.actions,
    super.key,
  });

  final String listLabel;        // "Alunos"
  final VoidCallback onBack;     // decidido pela tela, não pelo componente (ver abaixo)
  final Widget? leading;         // AppAvatarPicker (Aluno/Professor) — opcional
  final String title;            // "Paulo Sergio de Lima"
  final String? subtitle;        // ex.: "Plano Mensal" na Matrícula — opcional
  final Widget? trailing;        // AppBadge de status, ao lado do título
  final List<Widget>? actions;   // Editar/Inativar/Remover — a mesma lista de hoje
}
```

O componente **só cuida de apresentação e layout responsivo** (link de volta + info + ações, com o mesmo breakpoint mobile/desktop que cada tela já implementa individualmente hoje, duplicado 5x). Ele **não decide** para onde `onBack` navega — isso é local (ver próxima seção), porque cada tela já tem sua própria regra de "o que devolver pro chamador" (`_alterado`, `true`/`false`), e essa regra não deve virar responsabilidade do componente de UI.

### Navegação: reaproveitar o pop já existente, não criar um segundo caminho

Cada tela de detalhe já centraliza sua lógica de saída dentro do `PopScope`:

```dart
// Hoje (AlunoDetailScreen, por exemplo)
onPopInvokedWithResult: (didPop, result) {
  if (!didPop) context.pop(_alterado);
},
```

Proposta: extrair isso pra um método nomeado (`_voltar`) e apontar **tanto** o `PopScope` quanto o novo `AppDetailHeader.onBack` pro mesmo método — nunca duas implementações de "sair da tela" convivendo:

```dart
void _voltar() => context.backToList('/alunos', result: _alterado);

PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, _) { if (!didPop) _voltar(); },
  child: Scaffold(
    body: Column(children: [
      AppDetailHeader(listLabel: 'Alunos', onBack: _voltar, title: aluno.nome, ...),
      ...
    ]),
  ),
)
```

`context.backToList(listRoute, {result})` é uma extensão pequena e nova (`admin_web/lib/routing/`, não em `shared_core` — é regra de navegação específica das rotas do admin_web, não design system):

```dart
extension AppBackNavigation on BuildContext {
  void backToList(String listRoute, {Object? result}) {
    if (canPop()) {
      pop(result);
    } else {
      go(listRoute); // acesso direto por URL/reload — sem stack pra voltar
    }
  }
}
```

Isso resolve dois casos:
1. **Fluxo normal** (99% dos casos — sempre chegou aqui via `push()` a partir da lista): `canPop() == true`, então `pop(result)` — devolve pra mesma instância da lista, com filtro/busca/página intactos, idêntico ao que já acontece hoje com o botão do navegador.
2. **Entrada direta** (URL colada, aba recarregada em `/alunos/:id`): não há nada pra "pop" — `canPop() == false` — cai em `go('/alunos')`, uma lista nova e sem filtro (não tem como preservar um filtro que nunca existiu nesta aba). Sem esse fallback, o botão novo ficaria inerte nesse caso (pior do que hoje, onde o botão do navegador ao menos sai da aba/app).

Isso é o único trecho de lógica de navegação centralizado — evita 5 cópias do mesmo `if (canPop())`.

### Formulários (`*FormScreen`) — confirmado no escopo

`/alunos/novo` e `/alunos/:id/editar` têm exatamente o mesmo problema (fora do Shell, sem affordance de volta visível, `Cancelar` só no rodapé do formulário, que pode estar fora da viewport em formulários longos). A integração é mais simples que nas telas de detalhe — sem `actions`/`trailing`/`leading`, só `listLabel` + `title` ("Novo aluno"/"Editar aluno") + `onBack` apontando pro mesmo `Cancelar` que já existe hoje.

## Mapa completo de telas impactadas

| Entidade | Rota(s) | `listLabel` | `listRoute` (fallback) | Observação |
|---|---|---|---|---|
| Aluno | `/alunos/:id` | Alunos | `/alunos` | tem `leading` (avatar) |
| Aluno (form) | `/alunos/novo`, `/alunos/:id/editar` | Alunos | `/alunos` | confirmado no escopo |
| Professor | `/professores/:id` | Professores | `/professores` | tem `leading` (avatar) |
| Professor (form) | `/professores/novo`, `/professores/:id/editar` | Professores | `/professores` | confirmado no escopo |
| Turma | `/agenda/turmas/:id` | Turmas | `/agenda/turmas` | sem avatar |
| Turma (form) | `/agenda/turmas/novo`, `/agenda/turmas/:id/editar` | Turmas | `/agenda/turmas` | confirmado no escopo |
| Plano | `/planos/:id` | Planos | `/planos` | sem avatar |
| Plano (form) | `/planos/novo`, `/planos/:id/editar` | Planos | `/planos` | confirmado no escopo |
| Matrícula | `/matriculas/:id` | Matrículas | `/matriculas` | tem `subtitle` (plano); `actions` variável (até 4 botões conforme status) |
| Matrícula (form) | `/matriculas/novo`, `/matriculas/:id/editar` | Matrículas | `/matriculas` | confirmado no escopo |

**Fora de escopo** (não são rota, são diálogo sobre a própria lista — não têm o problema descrito): Mensalidade, Lançamento (Caixa), Modalidade, Aula (Calendário), Solicitação de reposição.

## Riscos e cuidados de implementação

- **Não duplicar a decisão de pop.** O `PopScope` de cada tela e o `AppDetailHeader.onBack` precisam chamar o **mesmo** método (`_voltar`) — nunca dois caminhos de saída com lógica própria, pra não arriscar comportamento divergente entre "clicar na seta" e "apertar back do navegador".
- **Formulários não têm `PopScope` hoje** — se entrarem no escopo, o `Cancelar` de cada um também passa a chamar o mesmo `_voltar()`/`backToList()`, sem duplicar a regra `canPop() ? pop() : go()`.
- **Nenhuma migration de query param.** Não é necessário serializar filtro/busca/página na URL da lista — o `push`/`pop` já resolve isso para o caminho normal (95%+ do uso real); só o caso de entrada direta por URL perde o filtro, e isso é esperado (não existia estado nenhum pra preservar).
- **`MatriculaDetailScreen`** tem até 4 botões de ação condicionais (`Trancar`/`Reativar`/`Renovar`/`Cancelar` + `Remover`) — o componente precisa aceitar `actions` como lista livre (`List<Widget>?`), não um conjunto fixo de 3 botões.

## Decisões confirmadas (2026-07-15)

1. **Texto do link**: `← Alunos` (só o rótulo da lista, sem "Voltar para").
2. **Formulários** (`novo`/`editar`) entram no mesmo escopo desta sprint — MS4 do plano abaixo deixa de ser opcional.
3. **Mensalidade/Aula ficam de fora** — são diálogo sobre a própria lista, não rota; não têm o problema descrito. Uma eventual rota própria de Mensalidade é iniciativa separada, não parte desta sprint.

## Plano de micro-sprints (proposto, não iniciado)

- **MS1 — Design System.** `AppDetailHeader` em `shared_core`, com um exemplo na galeria (`design_system_gallery_screen.dart`), coberto pelo mesmo padrão de review visual das outras sprints.
- **MS2 — Extensão de navegação.** `context.backToList()` em `admin_web/lib/routing/`.
- **MS3 — Integração nas 5 telas de detalhe** (Aluno, Professor, Turma, Plano, Matrícula), extraindo `_voltar()` em cada uma e trocando o bloco `info`/`acoes` solto pelo `AppDetailHeader`.
- **MS4 — Formulários** (`novo`/`editar` das 5 entidades), mesmo padrão.

Cada MS: `flutter analyze` limpo, testes de widget onde já existem, validação manual — mesmo padrão de todas as sprints anteriores.

## Histórico

**2026-07-15 — Implementado (MS1-MS4, todas de uma vez).** `AppDetailHeader` + `AppBackLink` em `shared_core` (com exemplo na galeria); `context.backToList()` em `admin_web/lib/routing/back_navigation.dart`; integrado nas 5 telas de detalhe e nos 5 formulários (Aluno, Professor, Turma, Plano, Matrícula), incluindo os estados de loading/erro (via `AppBackLink` isolado, já que `title` ainda não existe nesses estados). `flutter analyze` limpo em `shared_core`/`admin_web`, 12 testes de widget verdes. Validado visualmente num build de produção real (Playwright + Chromium headless): busca "Maria" em Alunos → abre detalhe → clica "← Alunos" → volta com o filtro intacto (sem refetch); e o caso de entrada direta por URL (`canPop() == false`) cai graciosamente em `go('/alunos')` sem quebrar.
