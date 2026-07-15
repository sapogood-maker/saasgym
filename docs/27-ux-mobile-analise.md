# Sprint de UX Mobile — Análise de domínio e responsividade

## O problema

O SaaSGym é usado hoje como PWA instalado no celular, e a experiência real é "desktop encolhido", não "desenhado pra toque". Este documento levanta, com números exatos do código atual, por que isso acontece e propõe uma estratégia de responsividade — confirmada em 2 níveis visuais (toque, cobrindo celular e tablet, vs. desktop inalterado) — mais um conjunto de ajustes no Design System, todos condicionados pra nunca mudar a experiência desktop. Nada foi implementado ainda.

## Diagnóstico — o que já existe (levantamento factual)

### 1. Breakpoints já existem, mas só um é usado de verdade

`AppBreakpoints` (`packages/shared_core/lib/src/design_system/tokens/app_breakpoints.dart`) já define `mobile = 600` e `tablet = 1024`, e `design_system_context.dart` já expõe `isMobile`/`isTablet`/`isDesktop` a partir desses dois cortes. **Mas `isTablet` nunca é consumido em lugar nenhum do código** (confirmado por grep em `shared_core` e `admin_web` inteiros — só aparece na própria declaração e em dois comentários). Na prática, o produto hoje é binário: `isMobile` (`<600`) ou "tudo o resto", o que significa que a faixa 600–1024 (tablet, e bastante celular grande em paisagem) recebe o mesmo layout do desktop, só que espremido.

### 2. Toda tipografia de corpo/campo está abaixo de 16px — causa raiz do problema de digitação (requisito 5)

`AppTypography` (`tokens/app_typography.dart`):

| Estilo | fontSize |
|---|---|
| displayLarge | 26 |
| titleLarge | 18 |
| titleMedium | 14.5 |
| **bodyMedium** | **14** |
| bodySmall | 12.5 |
| labelSmall | 11 |

`AppTextField`/`AppSelect`/`AppDateField` usam `bodyMedium` (14px) pro texto que o usuário efetivamente digita/vê dentro do campo. **Isso é a causa raiz #1 do requisito 5**: iOS Safari/WebView (e a maioria dos navegadores mobile) faz auto-zoom da página inteira ao focar um `<input>` cujo `font-size` computado é menor que 16px — é um comportamento do navegador, não do Flutter, e não tem como desativar sem corrigir a fonte. Todo campo do sistema hoje dispara esse zoom ao ser tocado: a tela "pula" de tamanho a cada toque num campo, o que é exatamente o sintoma relatado.

### 3. Áreas de toque abaixo do mínimo recomendado em quase todo componente interativo

Referência: Apple recomenda mínimo 44×44pt, Material Design recomenda 48×48dp. Medido no código atual:

| Componente | Altura/área de toque hoje | Abaixo do mínimo? |
|---|---|---|
| `AppButton` | 40px fixo | Sim (44/48) |
| `AppTextField`/`AppSelect`/`AppDateField` (via `AppFieldChrome`) | ≈37px (padding 8 vertical + linha de texto 14px) | Sim |
| `AppListTile` | ≈48px | No limite — ok |
| `AppPagination` (botões de página) | 30×30px | Sim, feio de errar com o dedo |
| `AppSidebar` — item de navegação | ≈35px | Sim |
| `AppHeader` — botões de ícone (menu/busca/notificações) | 34×34px | Sim |
| `AppSidebar` — menu do usuário (rodapé) | ≈46px | No limite — ok |

### 4. Três dos quatro componentes de composição mais usados não têm nenhuma lógica responsiva

Grep por `isMobile`/`MediaQuery`/breakpoint dentro de cada widget:

- `AppCard` — **zero** lógica responsiva. Padding fixo de 24px (`AppSpacing.xl`) em qualquer largura de tela.
- `AppListTile` — **zero** lógica responsiva.
- `AppPagination` — **zero** lógica responsiva.
- `AppFormRow` — **tem**: colapsa de `Row` (colunas lado a lado) pra `Column` (empilhado) quando `context.isMobile`. Esse é o único dos quatro que já pensa em mobile.

`AppListToolbar` (usado em toda tela de lista) também já colapsa (busca empilhada acima da `Wrap` de ações abaixo de 600px) — então **as telas não estão literalmente quebradas/overflowing no celular**, mas a adaptação que existe é herdada passivamente de dois componentes, não uma decisão deliberada de UX por tela.

### 5. Praticamente nenhuma tela pensa em mobile por conta própria

Inventário completo de `context.isMobile` em `admin_web/lib`: só 3 lugares usam a flag fora do Design System — `AppShell` (sidebar vira Drawer), `calendar_screen.dart` (toolbar e visão de semana empilham) e `painel_financeiro_screen.dart` (tabela de evolução vira cards). **Todo o resto — Alunos, Professores, Matrículas, Planos, Turmas, Caixa, Mensalidades, e todos os formulários e telas de detalhe dessas entidades — não tem nenhuma lógica mobile própria.** O que essas telas mostram no celular é 100% herdado dos primitivos do Design System (item 4), nunca pensado tela a tela.

### 6. Todo diálogo do sistema é um modal centralizado de largura fixa — nenhum bottom sheet

18 usos de `showDialog` espalhados por 9 arquivos (`AppConfirmDialog`, popover de notificações, diálogos de ação de Turma/Modalidade/Caixa/Mensalidade/Avaliação Física/Calendário/Reposições) — **todos** usam `Dialog` com `maxWidth`/`SizedBox` fixo entre 320 e 460px, centralizado, sem nenhuma variante mobile. `showModalBottomSheet` (o padrão nativo de mobile pra ação/formulário curto) tem **zero usos** no produto inteiro. Num celular de 375px de largura, isso vira um cartão pequeno flutuando no meio de uma tela escura — funciona, mas não é "desenhado pra toque": um bottom sheet full-width, que sobe do fundo da tela e é mais fácil de alcançar com o polegar, é o padrão que usuários de app mobile esperam.

### 7. PWA: sem decisão deliberada de viewport, e a cor de marca do manifest está errada

`admin_web/web/index.html` **não tem nenhuma tag `<meta name="viewport">`** — o comportamento de zoom/escala fica inteiramente a cargo do valor que o bootstrap do Flutter injeta em tempo de execução, nunca uma escolha deliberada do produto. Tags de PWA presentes: `mobile-web-app-capable` (a variante nova) mas **falta `apple-mobile-web-app-capable`** (a variante que versões mais antigas do iOS Safari exigem pra reconhecer o app como instalável em tela cheia).

Mais visível: `manifest.json` tem `background_color`/`theme_color` = **`#0175C2`** — esse é literalmente o azul padrão do template `flutter create`, nunca trocado. A cor real da marca (Dark Premium) é `#0B0B0B` (fundo) / `#C9A96A` (dourado). Isso significa que a splash screen/status bar do PWA instalado no Android mostra azul genérico do Flutter em vez da identidade visual do produto — um descuido fácil de corrigir, não uma decisão de design.

### 8. Sem tabela nem grid não-responsivo

Não há `DataTable`/`Table` em lugar nenhum do produto — toda listagem já é baseada em `AppListTile`/cards que naturalmente empilham. Isso é uma coisa boa: não existe o problema clássico de "tabela HTML que não cabe na tela".

## Por que a digitação é ruim no celular hoje — resposta direta ao requisito 5

Quatro causas, por ordem de impacto:

1. **Fonte do campo em 14px, abaixo do limiar de 16px que os navegadores mobile usam pra decidir se fazem auto-zoom ao focar.** É a causa dominante — a tela "pulando" de tamanho a cada toque num campo é exatamente esse comportamento do navegador reagindo à fonte pequena, não um bug do Flutter.
2. **Altura efetiva do campo (~37px) abaixo da área mínima de toque recomendada** — mira imprecisa, toque no campo errado.
3. **`keyboardType` semântico é opt-in por chamada, não garantido pelo componente** — não impede nada por si, mas é fácil um campo de telefone/CPF esquecer de passar `TextInputType.phone`/`.number` e abrir teclado alfabético completo à toa. Não auditei quantos call sites já acertam isso; é um item de verificação, não uma reescrita.
4. **Ausência de `<meta viewport>` explícito** deixa esse comportamento inteiro subordinado ao default do Flutter, sem controle do produto sobre a experiência.

A correção da causa #1 (fonte ≥16px em todo campo) sozinha já elimina o sintoma mais visível e incômodo (a tela "pulando"). É também a mudança de maior alavancagem: como `AppTextField`/`AppSelect`/`AppDateField` compartilham a mesma casca (`AppFieldChrome`, arquivo único), corrigir a fonte e o padding **num único lugar** já corrige every campo de formulário do sistema inteiro — nenhuma variação por módulo necessária, exatamente o padrão que este projeto já segue noutras sprints.

## Estratégia de responsividade proposta — confirmada em 2026-07-15

Decisão do dono do produto: **esta sprint tem 2 níveis visuais, não 3.** Tablet (600–1024px) usa exatamente o mesmo tratamento de celular — sem layout intermediário próprio agora. Desktop (`≥1024`) fica **pixel-idêntico** ao que é hoje; nada muda visualmente lá. Isso significa que todo ajuste de toque proposto neste documento é condicionado, nunca um novo padrão global do componente.

Consequência arquitetural direta: o corte relevante para "aplica toque ampliado" não é mais `context.isMobile` (`<600`) sozinho — precisa cobrir também a faixa de tablet (`600–1024`). Proposta: adicionar um getter novo e pequeno em `design_system_context.dart`, **reaproveitando os breakpoints que já existem, sem inventar número novo**:

```dart
/// true quando a tela é celular OU tablet — o corte que separa "layout de
/// toque" (Drawer, campos/botões ampliados, bottom sheet) de "layout de
/// desktop" (mouse, densidade atual, sem nenhuma mudança visual).
bool get isTouch => !isDesktop; // width < AppBreakpoints.tablet (1024)
```

`isMobile`/`isTablet`/`isDesktop` continuam existindo como estão (não removo nada) — `isTouch` é só um nome semântico pra "não é desktop", usado nos pontos do Design System listados abaixo. `isTablet` continua sem consumidor nesta sprint (fica disponível pra quando um layout de tablet dedicado for decidido no futuro).

| Nível | Largura | Navegação | Formulários | Diálogos | Toque (botão/campo/paginação/ícones) |
|---|---|---|---|---|---|
| **Celular + Tablet** (`isTouch`) | `<1024` | Drawer (hambúrguer) | 1 coluna (`AppFormRow` já faz isso) | Bottom sheet full-width | Ampliado (≥44px) |
| **Desktop** (`!isTouch`) | `≥1024` | Sidebar fixa (como hoje) | 2+ colunas (como hoje) | Modal centralizado (como hoje) | **Idêntico ao atual — sem nenhuma mudança** |

O ponto central da estratégia continua o mesmo: **a diferença entre os 2 níveis deve viver nos poucos componentes compartilhados do Design System (`AppButton`, `AppFieldChrome`, `AppCard`, `AppListTile`, `AppPagination`, `AppSidebar`, `AppHeader`, o chassi de diálogo), nunca em lógica duplicada por tela.** Como o levantamento acima mostrou que quase nenhuma tela tem lógica mobile própria hoje, e as poucas que têm (`AppShell`, Calendário, Painel Financeiro) já delegam a decisão de layout a `context.isMobile`, esse é o padrão a manter e estender — não um padrão novo.

## Ajustes globais propostos no Design System

Cada item abaixo é uma mudança num componente único, reutilizada em toda a tela que já o usa — sem exceção por módulo. **Todos os itens de toque (2, 3, 4, 5, 6, 7, 8) são condicionados a `context.isTouch` — o desktop não muda em nenhum deles.** Só o item 1 (fonte do texto digitado) e o item 10 (PWA) valem pra sempre, porque não têm efeito visual em desktop (fonte de campo ≥16px é imperceptível numa tela grande; viewport/manifest não têm equivalente desktop).

1. **Tipografia de campo — vale em qualquer tela.** Criar um estilo dedicado (ex.: `AppTypography.inputText`, 16px) só pro texto editável dentro de `AppFieldChrome`/`AppTextField`/`AppSelect`/`AppDateField`. Não subir `bodyMedium` em si (14px é usado em muito mais lugar que só input — texto de lista, corpo de card — mudar o valor base espalharia o efeito pra onde não é o problema). Sem impacto visual perceptível em desktop.
2. **`AppFieldChrome`.** Quando `context.isTouch`, subir o padding vertical (hoje `AppSpacing.sm`=8 sempre) o suficiente pra altura efetiva do campo passar de ~37px pra ≥44px. Em desktop mantém o padding atual, pixel a pixel.
3. **`AppButton`.** Quando `context.isTouch`, altura mínima 44-48px (hoje 40px fixo em qualquer tela). Em desktop continua 40px — nenhuma mudança.
4. **`AppPagination`.** Quando `context.isTouch`, botões de página de 30×30 pra pelo menos 40×40 — mesma paginação por número (decidido: não trocar por scroll infinito). Em desktop continua 30×30.
5. **`AppSidebar` — item de navegação.** Aumentar a altura de toque (~35px hoje) só quando renderizado dentro do `Drawer` (que já só aparece em `isTouch` hoje, via `AppShell`) — a versão fixa de desktop não muda.
6. **`AppHeader` — botões de ícone.** Quando `context.isTouch`, 34×34px hoje → 44×44px. Desktop continua 34×34.
7. **Chassi de diálogo.** Decidido: todos os 18 usos de `showDialog` viram bottom sheet full-width quando `context.isTouch` — sem exceção por tipo de diálogo. Em desktop continuam exatamente como hoje (modal centralizado). Proposta de implementação: um helper único (ex.: `showAppDialog(context, builder: ...)`) que decide `showDialog` vs. `showModalBottomSheet` internamente conforme `isTouch`, pra cada um dos 18 call sites trocar só a chamada, sem reescrever o conteúdo interno de cada diálogo.
8. **`AppCard`.** Quando `context.isTouch`, padding reduzido de 24px pra ~16px (`AppSpacing.lg`) — mais espaço útil numa tela de 375px. Desktop continua 24px.
9. **`AppListTile`.** Já está no limite aceitável (~48px) em qualquer tela — sem mudança estrutural, só confirmar que a área clicável cobre a linha inteira (não só o texto). Nenhuma diferenciação por breakpoint necessária aqui.
10. **PWA — vale em qualquer tela (não tem equivalente "desktop" pra preservar).** Adicionar `<meta name="viewport">` explícito permitindo zoom manual do usuário (decidido: sem `maximum-scale`/`user-scalable=no` — o auto-zoom incômodo já é resolvido pela causa raiz, fonte ≥16px); adicionar `apple-mobile-web-app-capable`; corrigir `theme_color`/`background_color` do `manifest.json` de `#0175C2` (azul padrão do Flutter) pra `#0B0B0B`/`#C9A96A` (a marca real, Dark Premium).

## Telas impactadas

Como a estratégia concentra a mudança nos componentes compartilhados, o impacto nas telas é majoritariamente **automático/herdado** — qualquer tela que já usa `AppButton`/`AppTextField`/`AppCard`/`AppListTile`/`AppPagination` ganha o ajuste sem precisar de código próprio. Isso cobre a imensa maioria do produto: Alunos, Professores, Matrículas, Planos, Turmas (listas, detalhes e formulários), Financeiro (Mensalidades, Caixa, Painel).

Exigem atenção própria (porque compõem diálogos customizados, não só os primitivos):
- `MatriculaDetailScreen` (diálogo de cancelamento com `AppSelect`/`AppTextField` — vira bottom sheet)
- `TurmaDetailScreen` (5 diálogos: recorrência, aula extra, matrícula em turma etc.)
- `AlunoDetailScreen` (diálogo de nova avaliação física)
- `ModalidadesScreen`, `CaixaScreen`, `MensalidadesScreen`, `ReposicoesScreen`, `CalendarScreen`, `AppShell` (popover de notificações)

Essas telas não precisam de redesenho — só trocar a chamada de `showDialog` pelo helper novo (item 7 acima), depois de ele existir.

Telas que já têm lógica mobile própria e devem ser reavaliadas **depois** do Design System atualizado (podem simplificar ou ficar como estão): `AppShell`, `calendar_screen.dart`, `painel_financeiro_screen.dart`.

## Decisões confirmadas (2026-07-15)

1. **Tablet usa o mesmo tratamento de celular nesta sprint** — sem layout intermediário próprio. Introduz o getter `isTouch` (`isMobile || isTablet`, `<1024`) pra expressar isso sem duplicar breakpoint em cada componente.
2. **Desktop fica pixel-idêntico** — nenhum ajuste deste documento tem efeito visual em `≥1024`; todos os itens de toque são gated por `isTouch`.
3. **Todos os 18 diálogos viram bottom sheet** quando `isTouch`, sem exceção por tipo — desktop continua modal centralizado.
4. **`AppPagination`**: botões maiores (≥40×40), mantém paginação por número — não vira scroll infinito.
5. **Viewport do PWA**: permite zoom manual do usuário (sem `maximum-scale`/`user-scalable=no`).
6. **`manifest.json`**: corrige `theme_color`/`background_color` pra `#0B0B0B`/`#C9A96A` (marca real).

## Plano de micro-sprints (proposto, não iniciado)

- **MS1 — Tipografia e toque nos campos.** `AppTypography.inputText` (16px) + `AppFieldChrome` com altura ≥44px em `isTouch`. Maior alavancagem, resolve o requisito 5 sozinho.
- **MS2 — `isTouch` + touch targets dos demais componentes.** Getter novo em `design_system_context.dart`; `AppButton`, `AppPagination`, `AppSidebar` (item de nav), `AppHeader` (botões de ícone), `AppCard` (padding), todos gated por `isTouch`.
- **MS3 — Diálogos.** Helper `showAppDialog`/variante bottom sheet; migrar os 18 call sites.
- **MS4 — PWA.** `<meta viewport>`, `apple-mobile-web-app-capable`, cores do `manifest.json`.

Cada MS: `flutter analyze` limpo, testes de widget onde já existem, validação manual num dispositivo/emulador real (não só reduzir a janela do navegador) — mesmo padrão de todas as sprints anteriores. Verificação obrigatória em cada MS: comparar screenshot desktop antes/depois — precisa ser pixel-idêntico.

## Histórico

**2026-07-15 — MS1 implementado.** `AppTypography.inputText` (16px) criado; `AppTextField`/`AppSelect`/`AppDateField` passam a usar `inputText` em vez de `bodyMedium` quando `context.isTouch`, desktop mantém `bodyMedium`. `AppFieldChrome` sobe o padding vertical de `sm`(8) pra `md`(12) em `isTouch`, levando a altura efetiva do campo de ~37px pra ~48px. Getter `context.isTouch` (`!isDesktop`) adicionado em `design_system_context.dart`, usado já aqui e reservado pros próximos MS. `flutter analyze` limpo em `shared_core`/`admin_web`, 12 testes de widget verdes. Validado visualmente (Playwright, build de produção): formulário "Novo aluno" comparado em viewport desktop (1440px) e mobile (375px) — mobile mostra campos visivelmente maiores (texto e altura), desktop idêntico ao padrão anterior (a mudança é condicionada a `isTouch`, não executa em `isDesktop`).

**2026-07-15 — MS2 implementado.** Todos os itens gated por `context.isTouch`, desktop sem nenhuma mudança: `AppButton` (40→44px), `AppPagination._StepButton` (30×30→40×40), `AppSidebar._NavItem` (padding vertical maior no item de navegação, mais perceptível dentro do `Drawer` mobile), `AppHeader._HeaderIconButton`/`_NotificationsButton` (34×34→44×44), `AppCard` (padding default 24→16px quando não há `padding` explícito — call sites que já passavam padding próprio continuam intactos). `flutter analyze` limpo, 12 testes de widget verdes. Validado visualmente: tela de Alunos comparada em desktop (botões/paginação idênticos ao anterior) e mobile (botão "Novo aluno", paginação e itens do Drawer visivelmente maiores).

**2026-07-15 — MS3 implementado.** `showAppDialog<T>()` novo em `shared_core` (`widgets/overlays/app_dialog.dart`) — decide `showDialog` (desktop, casca idêntica à anterior, agora com `SingleChildScrollView` embutido pra nunca estourar em tela baixa) vs. `showModalBottomSheet` (`isTouch`, full-width, cantos arredondados só no topo, alça de arraste, padding que soma o teclado) a partir do mesmo `builder`. `AppConfirmDialog` migrado (dogfooding). Todos os 18 usos de `showDialog` em `admin_web` migrados pra `showAppDialog` — 9 arquivos (`aluno_detail_screen`, `matricula_detail_screen`, `turma_detail_screen` ×5, `modalidades_screen` ×2, `caixa_screen` ×2, `mensalidades_screen`, `calendar_screen` ×3, `reposicoes_screen` ×2) mais o popover de notificações do `app_shell.dart` — cada diálogo teve seu próprio `Dialog`/`Padding`/`ConstrainedBox` removido, sobrando só o conteúdo (título, campos, botões); a largura máxima de cada um virou parâmetro no call site. `_showComingSoonPopover` (`AppHeader`) deliberadamente **não** migrado — não segue o contrato "só conteúdo" (já é um `EmptyState` com decoração própria) e é um placeholder de baixíssimo uso, fora do escopo aprovado de "diálogos de ação". Confirmado por grep: zero `showDialog<` restante em `admin_web/lib`. `flutter analyze` limpo em `shared_core`/`admin_web`, 12 testes de widget verdes. Validado visualmente: diálogo "Nova modalidade" idêntico em desktop (card centralizado) e, no mobile, sobe como bottom sheet de verdade (alça de arraste, cantos arredondados, ancorado no fundo).

**2026-07-15 — MS4 implementado.** `<meta name="viewport">` explícito + `<meta name="theme-color" content="#0B0B0B">` + `apple-mobile-web-app-capable` adicionados em `admin_web/web/index.html`; `manifest.json` corrigido de `#0175C2` (azul padrão do Flutter) pra `#0B0B0B` (fundo Dark Premium) em `theme_color`/`background_color`. **Achado real durante a implementação**: o engine do Flutter web remove qualquer `<meta name="viewport">` do HTML e injeta o próprio, hardcoded com `maximum-scale=1.0, user-scalable=no` — confirmado inspecionando `main.dart.js` compilado (função interna que faz `querySelectorAll('meta[name="viewport"]')` + `remove()` + recria a tag). Isso significa que só editar o HTML **não** cumpria a decisão de permitir zoom manual — o engine sobrescrevia silenciosamente. Corrigido com um `MutationObserver` em `index.html` que observa `document.head` e reaplica o `content` permissivo sempre que o engine reescreve a tag (não é um evento único — o comportamento pode repetir, ex. a cada foco de campo). Validado via Playwright: o valor do `content` da tag permanece `width=device-width, initial-scale=1` antes da inicialização do engine, depois dela, e depois de focar um campo de texto — nas três checagens a correção do engine foi neutralizada com sucesso.
