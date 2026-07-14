# Revisão de UX da Agenda — Análise (sem implementação)

Documento de análise, não de execução. Nenhum código, schema ou componente novo é proposto aqui — só a leitura crítica da proposta trazida após o uso real do sistema, confrontada com o que já existe hoje no código.

## 0. O que a Agenda já é hoje (para não criticar às cegas)

Antes de avaliar a proposta, o levantamento factual do estado atual:

- **A visão padrão do `CalendarScreen` já é Semana**, não Dia (`_modo = _ModoCalendario.semana` — `calendar_screen.dart:77`). A percepção de "a tela abre em modo Dia" provavelmente vem de outra coisa (ver seção 4), não do código.
- **A visão Semana já é uma grade de 7 colunas lado a lado no desktop** (`_visaoSemana`, `Row` de `_ColunaDia`, uma por dia — `calendar_screen.dart:440-458`), com fallback empilhado no mobile. Estruturalmente, isso já é o "SEG—DOM lado a lado" pedido.
- **Cada dia já mostra as aulas daquele dia como chips** (`_ChipAula`), mas o chip só exibe `horaInicio` + nome da turma, em verde (agendada) ou riscado/cinza (cancelada) — **sem professor, sem ocupação, sem cor por nível de lotação**. Esse é o gap real, não a existência da visão semanal em si.
- **A visão Mês já existe**, com "+N mais" quando uma célula tem mais aulas do que cabe, e clicar num dia navega pra visão Dia daquele dia.
- **O clique numa aula já abre um diálogo com bastante conteúdo operacional**: modalidade, professor, duração, capacidade, alunos inscritos, status, e ações — Definir substituto, Cancelar aula, Registrar frequência (ou "Ver alunos / Solicitar reposição" quando cancelada), Remover. Ou seja, boa parte do conteúdo pedido pro "painel lateral" **já existe**, só não como painel lateral — como diálogo central (`Dialog`, `ConstrainedBox(maxWidth: 460)`), pequeno e modal.
- **A lista de alunos que aparece ao abrir uma aula é por ocorrência** (`AulaAluno` daquela `Aula` específica), não a lista de matriculados permanentes da Turma (`TurmaAluno`) — normalmente coincidem, mas não são a mesma coisa (reposições avulsas adicionam gente que não é `TurmaAluno`).
- **`TurmaDetailScreen` já é, hoje, a tela "centrada em Turma"** que a proposta imagina como nova: mostra professor titular, capacidade, recorrências, alunos matriculados (com contador "X de Y vagas ocupadas" — a mesma métrica de ocupação que a proposta quer no calendário, só que em outro lugar), e as aulas geradas. O problema não é a ausência de uma visão por Turma — é que a recepção não vive nela no dia a dia, vive no Calendário.
- **Não existe hoje nenhum padrão de painel lateral (`EndDrawer` ou equivalente) no Design System** — só o `Drawer` esquerdo de navegação mobile. Um painel lateral pra detalhe de aula seria o primeiro caso desse tipo de componente no produto.
- **Capacidade tem duas granularidades diferentes e ambas já existem, mas não estão conectadas na UI**: `Turma.capacidadeMaxima` (estrutural, quantos podem ser matriculados permanentemente — já mostrado em `TurmaDetailScreen`) e `Aula.capacidadeMaxima`/`totalAlunos` (snapshot da ocorrência, herdado da Turma no momento da geração, mas podendo divergir por reposições avulsas adicionadas depois — já existe no `AulaResponseDto`, usado hoje só nas regras de aprovação de reposição, nunca exibido visualmente no calendário).

Esse último ponto é o achado mais importante da análise técnica: **a proposta trata "ocupação" como um conceito único, mas o domínio já modela dois**, e cada pergunta da recepção listada no pedido usa um deles:

| Pergunta da recepção | Qual "ocupação" responde |
|---|---|
| "Em qual turma ainda existe vaga?" | Estrutural (Turma) — matrícula permanente |
| "Onde encaixo um aluno pra aula experimental?" | Da ocorrência (Aula) — quem realmente aparece naquele dia específico |
| "Quantos alunos há em cada turma?" | Ambíguo na pergunta, mas normalmente estrutural |

## 1. Crítica da proposta

A proposta acerta no diagnóstico geral (a Agenda é o centro operacional, e hoje ela expõe estrutura de dados — Aula, Recorrência — em vez de responder perguntas de operação), mas superestima o quanto falta construir. Boa parte do que está sendo pedido como "novo" (visão semana em colunas, diálogo com conteúdo operacional rico, "vagas ocupadas") **já existe**, disperso ou mal exposto. Isso muda o tamanho do esforço real de "redesenhar a Agenda" para "reorganizar e enriquecer o que a Agenda já tem" — uma diferença que importa pra estimar a próxima sprint.

Um ponto que a proposta não distingue e devia: **"visão operacional do dia a dia" e "encontrar vaga pra matricular/repor alguém" são duas ferramentas diferentes**, mesmo que ambas apareçam na tela de Agenda. A primeira é sobre "o que está acontecendo" (leitura); a segunda é sobre "onde cabe mais uma pessoa" (uma busca com critérios). Tratar as duas como a mesma evolução da mesma tela arrisca misturar um calendário de leitura rápida com um formulário de busca dentro do mesmo espaço visual.

## 2. Vantagens e desvantagens de cada ideia

**Visão Semana como padrão operacional / Mês como estratégico** — Vantagem: reforça uma distinção que já existe implicitamente no código (Mês já é só leitura, sem ação de registrar frequência a partir dele) e já é o padrão hoje. Desvantagem: nenhuma real, é só nomear uma intenção que o código já cumpre.

**Chips de aula mostrando ocupação com cor (🟢🟠🔴)** — Vantagem: alto valor com baixo custo — o dado (`totalAlunos`/`capacidadeMaxima` da Aula) já existe, é só exibir. Resolve de verdade a pergunta "quantos alunos há nessa aula hoje" sem abrir nada. Desvantagem: exige decidir os limiares (o que é "quase cheio"?) e o que fazer quando `capacidadeMaxima` é nulo (turma sem limite) — hoje esse caso já existe e simplesmente não mostra contagem em `TurmaDetailScreen`; o calendário precisaria da mesma regra.

**Painel lateral em vez de diálogo central** — Vantagem real: um painel lateral permite manter o calendário visível atrás enquanto se decide algo (ex.: olhar a lista de alunos de uma turma sem perder o contexto da semana) — hoje o diálogo cobre a tela e fechar/reabrir perde a posição de scroll/filtro. Desvantagem: é o primeiro componente desse tipo no produto (nenhum precedente de `EndDrawer`/painel persistente), maior custo de Design System do que parece à primeira vista, e todo o fluxo multi-view do `_AulaAcoesDialog` (menu → cancelar → substituto → frequência) precisaria ser adaptado pra um chassi diferente — não é só trocar o container visual.

**Agenda "orientada à Turma" em vez de à Aula** — Isso já existe (`TurmaDetailScreen`), então a ideia real não é criar essa visão, é decidir se ela devia estar mais perto ou embutida na tela de Calendário. Vantagem: reduz a necessidade de sair do Calendário pra ver quem está matriculado numa turma. Desvantagem: o domínio (docs/18) modela deliberadamente `Aula` como o fato do calendário e `Turma` como configuração — inverter isso na UI sem inverter no domínio pode confundir mais do que ajudar (ex.: "cancelar" é sempre uma ação sobre uma `Aula`, nunca sobre uma `Turma`; se a UI passar a tratar Turma como a unidade central, essa distinção operacional se perde visualmente).

**Botão "Encontrar vaga"** — Ideia com valor real (resolve diretamente "onde encaixo esse aluno"), mas é uma funcionalidade nova de verdade, não um ajuste de UX — precisa cruzar `Turma` + `Recorrencia` (dia/horário do padrão) + contagem de `TurmaAluno` (vaga estrutural), uma combinação que nenhum endpoint hoje faz. Ver seção 4.

## 3. Impacto na arquitetura existente

- **Nenhum impacto no backend** para os itens de "visualização" (cor por ocupação, reorganizar o que já é retornado pelo `AulaResponseDto`) — é dado que já existe, é só front.
- **Impacto de Design System real** só para o painel lateral — é a única peça que exige um componente/padrão genuinamente novo (algo como um `EndDrawer` ou painel persistente responsivo, com colapso pra modal em mobile). Todo o resto (cores de ocupação, reorganização de chip) usa peças que já existem (`AppBadge`, cores semânticas do tema).
- **"Encontrar vaga" exigiria backend novo**: uma consulta que hoje não existe em lugar nenhum (cruzar `Recorrencia.diaSemana`/`horaInicio` com vaga estrutural de `Turma`). Não é extensão de um service existente, é uma capacidade nova.
- **Nada disso exige migration** — todos os dados envolvidos (capacidade, ocupação, dia/horário de recorrência) já estão no schema desde o Módulo 4 MS1.

## 4. Conflitos com o domínio já implementado

- **Nenhum conflito de modelo de dados** — tudo que a proposta pede pra exibir já é modelado (Aula tem capacidade/ocupação própria; Recorrência tem dia/horário; Turma tem capacidade estrutural).
- **Um conflito conceitual real**: tratar "ocupação" como um número único no calendário, quando o domínio já tem dois conceitos (estrutural vs. da ocorrência) — se a UI mostrar só um número "18/20" sem dizer qual é, pode levar a decisão errada (ex.: recepção vê "18/20" numa aula de terça e assume que dá pra matricular permanentemente ali, quando na verdade aquele "18" inclui reposições avulsas só daquele dia).
- **A pergunta "a tela abre em modo Dia" não bate com o código** (já é Semana por padrão) — vale confirmar com quem testou se a percepção veio de outro fluxo (ex.: clicar "+N mais" no Mês leva pra Dia, e talvez tenha sido esse o caminho testado, não a abertura direta da tela).
- **"Turma como unidade operacional" tensiona com uma decisão já tomada em docs/18**: cancelamento, substituto, frequência e reposição são sempre operações sobre `Aula` (a ocorrência), nunca sobre `Turma`. Deslocar o centro de gravidade visual pra Turma sem mexer nisso pode criar a expectativa errada de que essas ações também valem "pra sempre" (nível Turma) quando na verdade são sempre pontuais (nível Aula).

## 5. Melhorias propostas

1. **Enriquecer o chip da visão Semana/Mês** com professor (abreviado) e badge de ocupação colorida (🟢/🟠/🔴, limiares a definir — ex. <70% verde, 70-99% laranja, 100% vermelho), reaproveitando os dados que o `AulaResponseDto` já traz. Maior ganho pelo menor custo de tudo que foi pedido.
2. **Distinguir visualmente as duas ocupações**: se o calendário mostrar a ocupação da ocorrência (`Aula`), isso precisa ficar claro que é "hoje/nesta data", não "vaga permanente" — a pergunta "em qual turma ainda existe vaga" continua melhor respondida pelo indicador estrutural que já existe em `TurmaDetailScreen`, não pelo número do dia.
3. **Evoluir o diálogo atual antes de trocar de container**: praticamente todo o conteúdo pedido pro painel lateral já está no `_AulaAcoesDialog` — o ganho real de virar painel lateral (não perder contexto da semana) pode ser parcialmente alcançado até sem painel lateral, ex. um diálogo mais largo/alto que deixa ver mais da semana ao fundo, como um passo intermediário mais barato antes de investir num componente novo de Design System.
4. **Adicionar acesso rápido à lista de matriculados da Turma a partir do calendário** (ex. um link "ver turma completa" dentro do diálogo/painel da aula, levando pra `TurmaDetailScreen`) — resolve "quais alunos pertencem a essa turma" sem duplicar a lista de matriculados dentro do calendário.
5. **"Encontrar vaga" como uma ferramenta de busca separada**, não um botão dentro da mesma superfície visual do calendário — ex. um diálogo/tela própria de busca (modalidade + dia + horário → lista de turmas com vaga estrutural), que pode inclusive reaproveitar visualmente o padrão de resultado de lista já usado em outras telas, sem precisar caber dentro da grade semanal.

## 6. Layout profissional sugerido (conceitual, sem componentes)

Inspiração combinada de Google Calendar/Outlook (grade temporal, cor por categoria, clique abre detalhe sem perder o calendário) e sistemas de gestão escolar/academia (foco em ocupação e "quem está em qual turma", não em duração exata do evento):

- **Cabeçalho da semana**: os 7 dias como colunas com data + dia da semana (já existe), navegação `← Semana anterior · Hoje · Próxima semana →` (já existe via `_StepButton`/"Hoje").
- **Dentro de cada coluna**: cada aula como um bloco (não precisa virar grade por horário-eixo-Y como o Google Calendar — o volume diário de uma academia costuma ser baixo o bastante pra uma lista vertical simples continuar legível, evitando a complexidade de posicionamento por duração/sobreposição que agenda de academia normalmente não tem). Cada bloco mostra: horário, nome da turma, professor (abreviado), badge de ocupação colorida.
- **Clique num bloco**: abre um painel de detalhe (lateral no desktop, tela cheia/bottom sheet no mobile — mesma responsividade que o resto do produto já pratica) com a mesma hierarquia de informação do diálogo atual (modalidade/professor/capacidade/ocupação no topo, lista de alunos abaixo, ações no rodapé) — não é conteúdo novo, é reorganização espacial do que já existe.
- **"Encontrar vaga"** como uma ação de topo separada (ex. ao lado de "Nova aula extra"), abrindo sua própria superfície de busca (critérios em cima, resultados embaixo) — deliberadamente fora da grade semanal, pra não competir visualmente com a leitura do calendário.
- **Mês** continua uma grade compacta, só leitura, sem ocupação detalhada por célula (o "+N mais" já existente é suficiente pra planejamento; detalhe fica pra quem entra na Semana/Dia daquela data).

## 7. Classificação: Sprint de Consolidação (Agenda) vs. módulo futuro

**Poderia entrar numa Consolidação da Agenda** (ajuste/enriquecimento do que já existe, sem capacidade de domínio nova):
- Badge de ocupação colorida nos chips da Semana/Mês (melhoria 1).
- Diferenciar visualmente ocupação-da-ocorrência vs. vaga estrutural (melhoria 2) — só clareza de rótulo/tooltip, dado já existe dos dois lados.
- Adicionar professor abreviado ao chip.
- Link "ver turma completa" a partir do diálogo de aula (melhoria 4).

**Deveria virar módulo/sprint futuro** (capacidade nova de domínio ou de Design System):
- Painel lateral persistente (`EndDrawer` ou equivalente) — primeiro componente desse tipo no produto, decisão de Design System que merece sua própria análise antes de construir (padrão de responsividade, como se comporta com múltiplas views internas como o diálogo atual já tem).
- "Encontrar vaga" — cruza `Turma`+`Recorrencia`+capacidade estrutural numa consulta que não existe hoje; é a peça com maior valor de produto de toda a proposta, mas também a única que exige domínio novo.

Meu ponto de vista: os itens de "Consolidação" acima são baratos e de alto retorno — dá pra fazer isso antes ou depois da Sprint 8 (Dashboard) sem grande custo de sequenciamento, já que não mexem em nada que o Dashboard vai consumir. O painel lateral e o "Encontrar vaga" merecem uma análise de domínio própria (como esta, mas com foco de implementação) quando chegar a vez — não recomendo decidir os dois nesta conversa, já que o pedido explícito foi só entender se a arquitetura suporta a evolução (suporta, com as ressalvas acima).
