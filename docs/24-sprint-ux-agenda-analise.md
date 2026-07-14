# Sprint de UX da Agenda — Análise (sem implementação)

Documento de análise, não de execução. Continuação direta de `docs/23-agenda-ux-revisao-analise.md` — aqui o objetivo é menor e mais concreto: transformar a Agenda atual numa ferramenta mais rápida de ler no dia a dia, sem redesenhar nada, sem domínio novo, sem schema novo, sem componente novo de Design System sem necessidade comprovada.

Cada item abaixo foi verificado direto no código (não é suposição) e classificado em uma de três categorias:

- 🟢 **Só frontend** — dado já existe no `AulaResponseDto`/modelos já carregados, é só exibir/reorganizar. Zero mudança de backend.
- 🟡 **Extensão pequena de leitura já existente** — o backend já faz a query/join necessária pra outra coisa; falta só adicionar um campo ao DTO de resposta. Não é uma consulta nova, é a mesma consulta devolvendo mais um campo.
- 🔴 **Precisaria de leitura nova** — dado não é alcançável com o que já é buscado hoje; exigiria uma query adicional (ainda que pequena). Sinalizado explicitamente onde aparece, pra decisão consciente.

## 1. Cards da visão Semana/Mês — o que dá pra adicionar

Estado hoje: `_ChipAula` mostra só `horaInicio` + nome da turma, cor verde/cinza-riscado por status.

| Informação pedida | Categoria | Onde já está |
|---|---|---|
| Professor | 🟢 | `AulaResponseDto.professorNome` já existe, só não é exibido no chip |
| Modalidade (ou identificação visual) | 🟢 | `AulaResponseDto.modalidadeNome`/`modalidadeId` já existem |
| Ocupação | 🟢 | `AulaResponseDto.totalAlunos` já existe |
| Capacidade | 🟢 | `AulaResponseDto.capacidadeMaxima` (nullable = ilimitada) já existe |
| Status da aula | 🟢 | `AulaResponseDto.status` já existe (já usado pro riscado atual) |
| Indicador de cancelada | 🟢 | Mesmo campo `status` — já existe visualmente (riscado), só precisa ficar mais evidente (cor/ícone, não só tachado) |
| Indicador de substituição (professor ≠ titular da Turma) | 🟢 | Calculável no cliente comparando `aula.professorId` com `turma.professorId` (titular) — a lista de Turmas já é carregada pra popular o filtro, então o dado já está na tela, só nunca foi cruzado com o professor da aula |

**Conclusão do item 1: tudo é 🟢.** Nenhum dos 7 pedidos exige tocar o backend — é reorganização visual de um chip que hoje esconde dado que a resposta já carrega.

**Risco a administrar, não a resolver com mais dado**: o chip é pequeno (uma coluna de 7 cabendo numa tela). Empilhar 6 informações por chip pode virar poluição visual em vez de clareza. Recomendo tratar isso como um problema de hierarquia (o que aparece sempre vs. o que aparece só ao focar/hover), não de espremer tudo em texto — mas isso é decisão de implementação, não de domínio, então não aprofundo layout aqui (pedido do usuário foi não propor componentes ainda).

## 2. Leitura rápida sem abrir a aula

As quatro perguntas listadas (onde há vaga / qual professor / quais canceladas / quais lotadas) são **todas respondidas pelos mesmos 4 campos do item 1** (professor, ocupação/capacidade, status, — e "lotada" é só ocupação == capacidade). Não há pergunta nova aqui, é a consequência direta de resolver o item 1. Não escrevo uma seção separada de "como" — layout fica pra proposta de implementação.

## 3. A questão da ocupação (estrutural vs. da ocorrência) — como representar sem confundir

Recapitulando o achado de docs/23: `Turma.capacidadeMaxima` (vaga permanente) e `Aula.capacidadeMaxima`/`totalAlunos` (snapshot da ocorrência, pode incluir reposições avulsas daquele dia) são dois números diferentes que hoje moram em lugares diferentes da UI (Turma → `TurmaDetailScreen`; Aula → em lugar nenhum visível).

Três formas de resolver isso na Agenda, do mais simples ao mais completo:

**Opção A — só mostrar a ocupação da ocorrência, com rótulo que deixa claro o que é.** O chip mostra "18/20" com um rótulo/tooltip do tipo "ocupação desta aula" (não "vagas da turma"). Simples, 🟢, zero ambiguidade nova introduzida — só não responde diretamente "em qual turma cabe mais um aluno pra sempre", que continua sendo pergunta de `TurmaDetailScreen`.

**Opção B — mostrar os dois números quando divergem.** Se `Aula.totalAlunos` for maior que a matrícula estrutural da Turma (ou seja, tem reposição avulsa naquele dia), mostrar um indicador extra ("+2 reposição" ou similar) além do número principal. Mais informativo, ainda 🟢 (todo dado já existe — `TurmaAluno` contra `AulaAluno` já são consultados em outros lugares do produto), mas exige lógica de comparação um pouco mais elaborada no frontend (buscar quantos dos `AulaAluno` daquela aula são `tipo = REPOSICAO`, não só o total).

**Opção C — expor as duas ocupações lado a lado sempre.** Estruturalmente mais correto, mas adiciona uma segunda métrica em cada chip — piora exatamente o risco de poluição visual citado no item 1. Não recomendo para esta sprint (curta, focada em UX imediata) — é melhor sanidade de domínio do que ganho real de leitura rápida.

**Recomendação**: Opção A agora (rótulo claro, sem ambiguidade, zero custo), com o link "Abrir Turma" do item 4 sendo o caminho natural pra quem quiser a vaga estrutural — não precisa estar nos dois lugares ao mesmo tempo.

## 4. Refinamentos do diálogo existente (sem painel lateral)

Tudo abaixo é reorganização de conteúdo que já está no `_AulaAcoesDialog` — nenhum dado novo:

- **Link "Abrir Turma"** — navegação pra `TurmaDetailScreen` (rota já existe, `/agenda/turmas/:id`) a partir do diálogo da aula. 🟢, é só um botão/link a mais chamando uma rota que já existe.
- **Resumo melhor organizado** — hoje o `_menu()` já mostra modalidade/professor/duração/capacidade/alunos/status como pares de rótulo-valor; "melhor organizado" aqui é hierarquia visual (o que é destaque vs. o que é detalhe secundário), não dado novo. 🟢.
- **Indicadores mais claros** — mesmo ponto do item 1 (status/cancelada/substituição), replicado dentro do diálogo em vez de só no chip. 🟢.
- **Ações mais evidentes** — os botões (Definir substituto, Cancelar, Registrar frequência/Solicitar reposição, Remover) já existem; "mais evidentes" é hierarquia de botão (primário vs. secundário vs. destrutivo), não ação nova. 🟢.

**Conclusão do item 4: tudo 🟢**, puramente reorganização do que já existe dentro do mesmo diálogo, sem virar painel lateral (conforme pedido explícito de não fazer isso agora).

## 5. Filtros rápidos

**Achado importante: Professor, Modalidade e Status já existem como filtro hoje**, junto com filtro por Turma e botão "Limpar filtros" (`_barraDeFiltros()`, `calendar_screen.dart:320`) — implementados na Sprint de Consolidação do Módulo 4. Não há nada para construir aqui além do que já está em produção.

**Sala**: `Turma.local` existe no schema (`String?`, texto livre — não é uma entidade própria tipo `Sala` com ID), mas **não é exposto hoje em `AulaResponseDto`** — o serviço já faz join com Turma pra trazer `turmaNome`/`modalidadeNome`, então adicionar `local` ao mesmo select é 🟡 (extensão pequena da mesma leitura, não uma consulta nova). Ressalva que importa antes de decidir implementar: por ser texto livre (não uma lista fechada de valores), filtrar por "Sala" nu backend só funciraria por igualdade exata de string — se duas turmas tiverem "Sala 1" e "sala 1" (variação de digitação), o filtro separaria os dois como valores diferentes. Vale confirmar se `local` já é preenchido de forma consistente nos dados reais antes de expor como filtro, ou se isso é só um campo de anotação livre hoje sem uso de filtro planejado.

**Recomendação**: implementar Professor/Modalidade/Status/Turma como estão (já prontos, nada a fazer) e tratar "Sala" como opcional — só vale a pena se a base de dados real já usa `local` de forma consistente; caso contrário, é esforço 🟡 com baixo retorno até o dado ganhar mais estrutura (ex.: virar entidade própria no futuro, fora de escopo aqui).

## 6. Resumo operacional no topo

O exemplo dado (`Hoje · 12 aulas · 186 alunos previstos · 3 cancelamentos · 2 reposições`) tem uma tensão que vale decidir antes de implementar: **"Hoje" fixo vs. o período atualmente visível na tela**.

- Se o resumo for sempre sobre o dia literal de hoje, e a recepção estiver navegando pela semana que vem, o resumo ficaria descolado do que está na tela (ou exigiria uma busca adicional só pra "hoje", fora da janela já carregada pra visão atual — isso seria 🔴, consulta nova).
- Se o resumo for sobre **o período atualmente carregado** (a mesma janela de dados que a tela já buscou pra desenhar Dia/Semana/Mês), o rótulo muda de "Hoje" pra "Esta semana"/"Este mês" conforme o modo, e o cálculo é inteiramente client-side sobre dado que já está em memória. 🟢, zero custo.

**Recomendação**: a segunda opção — resumo do período visível, rótulo adaptado ao modo (`Dia`→"Hoje", `Semana`→"Esta semana", `Mês`→"Este mês"). Resolve o pedido sem introduzir busca nova nem descolar o resumo do que está na tela.

Detalhando cada número do exemplo:

| Métrica | Categoria | Cálculo |
|---|---|---|
| Total de aulas | 🟢 | Tamanho da lista de aulas já carregada pro período em vista |
| Alunos previstos | 🟢 | Soma de `totalAlunos` de cada aula já carregada (já inclui reposições, já que `AulaAluno` de qualquer `tipo` conta) |
| Cancelamentos | 🟢 | Contagem de aulas com `status == CANCELADA` na mesma lista já carregada |
| Reposições | 🔴 | **Não é alcançável com o dado atual.** `AulaResponseDto.totalAlunos` é um total agregado (todos os `tipo` de `AulaAluno` somados) — não existe hoje um campo que diga quantos daqueles alunos são especificamente `tipo = REPOSICAO`. Contar reposições no período exigiria estender a consulta (ex.: um `totalReposicoes` por aula, calculado junto do `totalAlunos` que já é calculado) — pequena mas real extensão de leitura (mais parecida com 🟡 do que com uma feature nova, já que é o mesmo padrão de contagem que `totalAlunos` já faz, só com um filtro de `tipo` a mais).

**Recomendação para "reposições"**: como é a única métrica que não sai de graça do que já é buscado, sugiro decidir explicitamente: (a) incluir mesmo assim, aceitando a extensão pequena de backend (mesma categoria do campo `local`, item 5); ou (b) deixar de fora do resumo nesta sprint curta e reavaliar junto de uma eventual extensão futura da Agenda. Não tenho preferência forte — é a única peça de todo este documento que não é 100% gratuita.

## 7. Fora de escopo (confirmado, não revisitado aqui)

Painel lateral, drag-and-drop, "Encontrar vaga" e "agenda inteligente" continuam como evolução futura documentada em `docs/23`, seção 7 — nada muda nessa classificação.

## 8. Resumo por categoria (visão executiva)

- **🟢 Só frontend, zero mudança de backend**: chip enriquecido (professor/modalidade/ocupação/capacidade/status/cancelada/substituição), ocupação com rótulo claro (opção A), todos os refinamentos do diálogo (link Abrir Turma, resumo reorganizado, indicadores, ações), filtros Professor/Modalidade/Status/Turma (já prontos), resumo operacional (aulas/alunos previstos/cancelamentos) com rótulo adaptado ao modo.
- **🟡 Extensão pequena de leitura já existente**: expor `local` da Turma no `AulaResponseDto` (só se decidido implementar filtro por Sala); expor `totalReposicoes` por aula (só se decidido incluir no resumo operacional).
- **🔴 Não incluído nesta sprint**: qualquer coisa que exigisse consulta genuinamente nova (nenhum item foi classificado assim depois de aplicadas as recomendações acima).

## 9. Plano de micro-sprints (proposto)

- **MS1 — Chips + diálogo (100% frontend).** Enriquecer `_ChipAula` (professor, modalidade, ocupação com rótulo, capacidade, status, indicador de substituição calculado no cliente); refinar `_AulaAcoesDialog` (link Abrir Turma, hierarquia visual do resumo e das ações). Nenhuma mudança de backend.
- **MS2 — Resumo operacional (100% frontend, com uma decisão pendente).** Card de resumo no topo do `CalendarScreen`, calculado sobre a lista de aulas já carregada, rótulo adaptado ao modo (Dia/Semana/Mês). "Reposições" só entra se a extensão 🟡 (`totalReposicoes`) for aprovada antes — caso contrário, o resumo nasce com aulas/alunos previstos/cancelamentos e "reposições" fica pra depois.
- **MS3 (opcional, só se aprovado) — Extensões pequenas de backend.** `local` no `AulaResponseDto` (pra filtro de Sala) e/ou `totalReposicoes` por aula (pro resumo) — cada um é uma alteração isolada de DTO/service, sem schema novo, sem endpoint novo.

Cada MS: `flutter analyze` limpo, testes existentes verdes, validação manual — mesmo padrão de sempre.

## Histórico

- **2026-07-14 — decisão do usuário**: as duas extensões 🟡 (filtro por Sala, `totalReposicoes` no resumo) foram aprovadas ("pode incluir os dois"). Reordenação em relação ao plano original: como ambas as extensões de backend passaram a ser necessárias (não mais opcionais), a sequência muda pra **backend primeiro** — evita construir a UI de filtro/resumo duas vezes (uma sem o dado, outra com).
- **2026-07-14, MS1 (Backend — extensões pequenas, sem endpoint novo, sem migration)**: `AulaResponseDto` ganhou `local: string | null` (snapshot de `Turma.local`, mesmo join que já trazia `turmaNome`/`modalidadeNome`) e `totalReposicoes: number` (contagem de `AulaAluno` com `tipo = REPOSICAO` na aula — resolvida com uma segunda leitura filtrada da mesma relação `alunos` dentro do `include` já existente, já que `_count.select` só aceita um filtro por relação; sem consulta adicional ao banco). `ListAulasCalendarioQueryDto` ganhou o filtro `local` (igualdade exata — mesmo critério de todos os outros filtros do endpoint, texto livre sem normalização). Corrigido de passagem um bug latente que a adição introduziria: `where.turma` era montado só a partir de `modalidadeId`; ao adicionar `local` como segundo filtro possível da mesma relação, os dois agora são combinados num único objeto em vez de um sobrescrever o outro. 4 testes e2e novos (filtro por `local` com igualdade exata, `local` diferente retorna vazio, `totalReposicoes` conta só `tipo = REPOSICAO` mesmo com outro `AulaAluno` `MATRICULADO` na mesma aula, `local` nulo quando a Turma não define) — 126 unit + 341 e2e no total, todos verdes. `nest build` limpo.
- **2026-07-14, MS2 (Shared Core)**: `Aula` (model) ganhou `totalReposicoes`/`local`, espelhando o DTO do backend. `AulasApi.listCalendario` ganhou o parâmetro `local`. Nenhum outro lugar do produto constrói `Aula` diretamente (só o próprio model e `Aula.fromJson`), então não houve nenhum ponto de chamada pra ajustar além da própria API. `flutter analyze` limpo em `shared_core`/`admin_web`, 27 + 12 testes inalterados e verdes.
- **2026-07-14, MS3/MS4 (Frontend — chips, diálogo, filtro de Sala e resumo operacional, todos os itens da sprint)**: implementados juntos (a divisão MS1/MS2 original virou só backend/shared_core; todo o restante do plano coube num único incremento de frontend coerente). `_ChipAula` ganhou o parâmetro `detalhado` — a visão Semana passa `detalhado: true` (professor + ocupação colorida + indicador de substituto, 2ª linha do chip), a visão Mês (`_CelulaMes`) continua chamando sem esse parâmetro (default `false`), preservando exatamente o comportamento minimalista já decidido em docs/23 ("Mês é estratégico"). Identificação visual de Modalidade via uma borda esquerda de 3px colorida (`Modalidade.cor`, já carregada em `_modalidades` — reaproveitado o parser `_corDeHex` já existente em `modalidades_screen.dart`, duplicado (6 linhas) em vez de extraído pro Design System). Ocupação sempre rotulada como "da aula" (opção A de docs/24, item 3): `_tomOcupacao`/`_rotuloOcupacao` (limiares 70%/100% → verde/laranja/vermelho, neutro quando `capacidadeMaxima` é nulo) usados tanto no chip quanto no diálogo — a vaga estrutural da Turma nunca aparece nesses dois lugares, só em `TurmaDetailScreen` (acessível agora via o novo botão "Abrir Turma" no diálogo). Indicador de substituto (`aula.professorId != turma.professorId` titular) calculado inteiramente no cliente, usando a lista de Turmas já carregada pro filtro — nenhuma consulta nova, nenhum campo novo pedido ao backend pra isso. `_AulaAcoesDialog` ganhou o parâmetro `turma` (nulo só se a Turma não estiver entre as ativas já carregadas); `_menu()` ganhou uma linha de badges (status/ocupação/substituto) no topo, o campo `Local` (quando presente) e o botão "Abrir Turma" (fecha o diálogo e navega via `context.go`, primeira vez que este arquivo importa `go_router` diretamente). Filtro de Sala na barra de filtros — só aparece quando pelo menos uma Turma carregada tem `local` preenchido (evita mostrar um filtro sempre vazio), populado com os valores distintos já presentes em `_turmas`. Resumo operacional (`_resumoOperacional`) — 4 `MetricCard`s (Aulas/Alunos previstos/Cancelamentos/Reposições) calculados sobre a lista de Aulas já carregada pro período em vista, rótulo reaproveitando `_rotuloJanela` (já existente, usado no cabeçalho de navegação) em vez de um texto novo — resolve o "Hoje fixo vs. período visível" exatamente como recomendado (docs/24, item 6): ao mudar de Semana pra Mês ou navegar pra outra semana, o resumo sempre reflete o que está na tela, sem chamada adicional. Nenhum componente novo do Design System — só reorganização/reuso do que já existia (`AppBadge`, `MetricCard`, `AppButton`). `flutter analyze` limpo, 27 + 12 testes inalterados e verdes, `flutter build web --release` ok.
  - **Validação manual (Playwright, build de produção, `admin@academiademo.com`)**: criados dados de teste cobrindo os 3 limiares de ocupação (verde/laranja/vermelho), uma aula cancelada, uma aula com professor substituto, e uma 2ª turma sem `local` definido (pra confirmar que o filtro de Sala só mostra os valores que existem e que a 2ª turma some do resultado ao filtrar por "Tatame 1"). Confirmado visualmente: badges de ocupação com as 3 cores nos limiares certos; "Cancelada" e "Substituto" evidentes tanto no chip (Semana/Dia) quanto no diálogo; resumo recalcula corretamente ao aplicar o filtro de Sala (8→6 aulas, 46→40 alunos previstos) e ao trocar de Semana pra Mês; "Abrir Turma" navega corretamente pra `TurmaDetailScreen`, onde ficou visível a diferença entre a ocupação estrutural ("1 de 20 vagas ocupadas", matrícula permanente) e a ocupação por ocorrência mostrada no calendário (5/20, 15/20, 20/20 em datas diferentes da mesma turma) — confirmação prática de que os dois conceitos de docs/24 item 3 não se confundem na UI. Mês confirmado inalterado (chips minimalistas, sem regressão). Mobile validado — resumo empilha em coluna, chips mantêm todas as informações sem overflow. Dados de teste (turmas/professores/modalidade/aulas/alunos criados só pra validação) removidos ao final. `nest build`/`flutter build web` limpos, 126 unit + 341 e2e (backend) e 27 + 12 (Flutter) inalterados e verdes.
  - **Sprint de UX da Agenda concluída** — os 6 objetivos do pedido original (cards da Semana, leitura rápida sem abrir aula, ocupação estrutural vs. da ocorrência, refinamento do diálogo, filtros rápidos, resumo operacional) entregues. Painel lateral, drag-and-drop, "Encontrar vaga" e "agenda inteligente" permanecem documentados como evolução futura (docs/23, seção 7) — não implementados nesta sprint, conforme escopo confirmado.
- **2026-07-14 — revisão final pré-commit: filtro por Sala removido**. Antes do commit, o dono do produto pediu uma reavaliação honesta contra 3 critérios (regra de domínio, complexidade desnecessária, dependência criada pra uma futura entidade `Sala`). Resultado: o filtro passa no primeiro critério (nenhuma regra de negócio alterada, mesma categoria dos filtros já existentes), mas falha o segundo — não estava entre as perguntas explícitas da recepção que motivaram a sprint (era um item "se existir" desde o pedido original, seção 5), e a própria recomendação original desta análise já havia sido cautelosa quanto a implementá-lo (condicionada à consistência real do dado, nunca uma recomendação forte). Também introduziu, de passagem, o único bug latente real corrigido nesta sprint (merge de `where.turma` pra não sobrescrever `modalidadeId`) — um risco que só existiu porque o filtro foi adicionado. E falha o terceiro critério: cria uma pequena superfície (query param `local`, rótulo "Sala" na UI) que uma eventual entidade `Sala` própria teria que migrar depois. Removidos: `ListAulasCalendarioQueryDto.local`, o filtro correspondente em `AulasService.listCalendario` (revertido pra atribuição simples de `where.turma`, já que só `modalidadeId` continua usando essa chave), o teste e2e "filtra por local (sala)", o parâmetro `local` de `AulasApi.listCalendario`, e toda a UI do filtro em `CalendarScreen` (`_localFiltro`, `_locaisDisponiveis`, o `AppSelect` de Sala, e as referências em `_temFiltroAtivo`/`_limparFiltros`/`_carregar`). **Mantido intacto**: o campo `local` no `AulaResponseDto`/`Aula` (exibido no chip e no diálogo, sem nenhum dos três problemas acima) e `totalReposicoes` (decisão separada, não questionada nesta revisão). 126 unit + 340 e2e (backend, um teste a menos) e 27 + 12 (Flutter) — todos verdes, `nest build`/`flutter analyze` limpos.
