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

Cada MS: `flutter analyze` limpo, testes existentes verdes, validação manual — mesmo padrão de sempre. Sem Histórico ainda, aguardando aprovação antes de qualquer código.
