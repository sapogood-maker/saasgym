# Release Review — SaaSGym v1.0 (pré-piloto)

Auditoria de produto realizada em 2026-07-17, antes da primeira academia real (piloto) usar o sistema. **Nenhum código foi alterado** — isto é 100% avaliação. Metodologia: leitura completa (não amostral) de todas as telas de produto do `admin_web` e dos componentes de design system que elas usam, mais uma inspeção visual ao vivo (build de release + backend real + dados de demonstração realistas, capturada em desktop 1440px, tablet 768px e mobile 390px) para confirmar o que só aparece em execução — responsividade, contraste, truncamento de texto, comportamento de dropdown/gráfico.

Papel assumido: Product Owner + UX Designer + QA + dono de academia entrando no sistema pela primeira vez, sem paciência para clicar em botões que não fazem nada.

---

## 1. Resumo Executivo

O núcleo do produto está pronto para vender. Dashboard, navegação principal, autenticação, o modelo de Matrículas/Mensalidades (reforçado recentemente pela Sprint de Integridade Financeira) e a separação conceitual Turma/Aula estão bem resolvidos, com disciplina real de design system (paleta Dark Premium aplicada quase sem exceção) e um padrão de confirmação/empty-state consistente na maioria das telas.

Mas a auditoria encontrou **um bug funcional que bloqueia a ação mais frequente do dia a dia** (marcar presença no próprio dia da aula) e um **conjunto concentrado de falhas exatamente nas bordas que um usuário novo toca primeiro**: a tela de Perfil (mensagem de erro crua, cargo exibido sem tradução, estrutura de tela duplicada), uma rota de catálogo interno de componentes acessível em produção por qualquer usuário logado (com um exemplo que alega, incorretamente, que o Financeiro "ainda não existe"), e uma sidebar que não é filtrada por papel — um recepcionista ou professor vê itens que só vão gerar erro 403 ao clicar.

O módulo Financeiro — o mais sensível, porque envolve dinheiro real — tem dois problemas que merecem atenção antes do piloto: a tabela de evolução mensal do Painel Financeiro não trata o caso de "sem dado ainda" (o que **toda** academia nova vai ver no primeiro acesso), e existe uma divergência de nomenclatura/cálculo entre "Receita Recebida" (Painel) e "Receitas" (Caixa) que pode fazer os números parecerem não bater.

Nenhum destes problemas exige redesenho — são, em sua maioria, correções pontuais e bem localizadas. O volume total de achados (40, a maioria Baixo/Cosmético) reflete o pedido de rigor desta revisão, não um produto malfeito: boa parte já estava mapeada em auditorias anteriores (placeholders "Em breve" remanescentes em Professor/Plano) e é trabalho conscientemente adiado, não esquecido.

---

## 2. Pontos fortes do sistema

- **Dashboard** é a melhor tela do produto: hierarquiza exatamente o que o dono da academia precisa ver primeiro (inadimplência → agenda do dia → navegação rápida), tem empty states acionáveis em toda seção, e não tem nenhum placeholder de desenvolvimento.
- **Separação Turma (estrutura recorrente) vs Aula (ocorrência específica)** está bem resolvida tanto conceitualmente quanto no código — nenhuma tela usa os dois termos como sinônimos, e o badge "Substituto" só aparece quando o professor da ocorrência realmente diverge do titular.
- **Confirmações destrutivas calibradas corretamente** na maioria das telas de Agenda (cancelar aula, remover modalidade/turma/recorrência) — nem burocráticas demais, nem descuidadas; o texto de `_AcoesTurmaAlunoDialog` ("use 'Sair da turma' em vez de Remover") é um exemplo de escrita de UX que deveria ser copiado em outros lugares do produto.
- **Marcar presença não pede confirmação** — acerto de calibração: é uma ação frequente e reversível, não deveria ter fricção (o problema aqui é outro, ver Crítico #1).
- **Matrículas**: nomenclatura "Fim previsto" vs "Fim vigente" resolve bem uma ambiguidade real do domínio; a tela de renovação já comunica a mudança de comportamento trazida pela Sprint de Integridade Financeira (valor/vencimento vêm da própria matrícula, ajustáveis depois).
- **Mensalidades**: distinção clara entre "Remover" (erro de cadastro) e "Cancelar" (cobrança de verdade) evita o erro clássico de confundir os dois; empty state por competência já oferece "Gerar mensalidades do mês" como ação primária.
- **Relatórios**: primeira tela do produto com gráfico de verdade (`fl_chart`), bem executada — paleta semântica respeitada (verde/vermelho só como estado, dourado só como marca), empty states dos dois gráficos corretamente tratados.
- **Sprint de Integridade Financeira** (já implementada, backend) resolveu riscos estruturais reais antes que afetassem clientes reais: geração automática de mensalidade, bloqueio de exclusão de Plano vinculado, renovação que não lê mais o Plano ao vivo.
- **Nomenclatura de ações 100% consistente** entre Alunos/Professores/Planos — "Editar"/"Inativar"/"Reativar"/"Remover" são idênticos nos três, mesma ordem, mesmas cores. Não há "Excluir" vs "Deletar" divergindo por entidade.
- **Guard de autenticação e navegação "voltar"** sólidos — preservam corretamente filtro/busca/paginação da lista de origem, sem bug encontrado.
- Nenhum texto de desenvolvimento ("Em breve", "TODO", "Sprint", "MSx") foi encontrado em nenhuma tela de Agenda, Reposições, Avaliação Física ou Frequência — módulos "limpos" nesse critério.

---

## 3. Problemas encontrados

### 3.1 Agenda / Frequência (o módulo mais usado no dia a dia)

**[Crítico] Presença não pode ser marcada no mesmo dia da aula.**
`calendar_screen.dart:959-961` — `_aulaRealizada()` compara só a **data** (`aula.data.isBefore(_somenteData(DateTime.now()))`), ignorando a hora (`horaInicio`). Uma aula de hoje às 7h nunca é "realizada" antes de amanhã, e o botão "Registrar frequência" só aparece quando `_aulaRealizada()` é verdadeiro. Um professor que dá aula às 7h e quer marcar presença às 8h **não consegue** — o botão não existe até o dia seguinte. Ataca de frente o uso mais comum e frequente do sistema.

**[Alto] Opção "Não marcada" no seletor de presença não faz nada.**
`calendar_screen.dart:1006-1017,1364` — a opção existe e é selecionável, mas `_registrarPresenca` tem `if (presenca == null) return;` — early return sem chamada de API. O backend (`aula_alunos_api.dart:26`) não tem operação de "desmarcar". Um erro de marcação (marcou presente errado) não pode ser revertido ao estado neutro.

**[Alto] Sem ação em lote para marcar presença da turma inteira.**
`calendar_screen.dart:1338-1379` — cada aluno tem seu próprio dropdown individual. Para 15-20 alunos, são ~30-40 interações pra bater a chamada de uma aula inteira, sem atalho pro caso mais comum (maioria presente, poucas exceções).

**[Médio] "Vagas da Turma" e "ocupação da Aula" são visualmente idênticas.**
Ambas aparecem como "X/Y" (`turma_detail_screen.dart:1061-1067` vs. badges do Calendário) sem rótulo diferenciador. O código sabe a diferença (capacidade estrutural vs. ocupação da ocorrência específica, que pode incluir reposição), a tela não fala — evidenciado justamente quando os dois números divergem (aula com reposição).

**[Baixo] Empty state do filtro padrão de Reposições não avisa que há filtro aplicado.**
`reposicoes_screen.dart:129-132` — a tela abre com filtro "Pendente"; se não houver nenhuma, o empty state não menciona que dá pra ver aprovadas/rejeitadas ajustando o filtro.

**[Baixo] Ações "Cancelar aula"/"Definir substituto" disponíveis para aulas já passadas.** Nenhuma checagem de `_aulaRealizada()` nesses dois fluxos.

**[Cosmético] "Ilimitado" (masc.) vs "Ilimitada" (fem., correto) inconsistente.** `turma_form_screen.dart:229` usa a forma errada; `turma_detail_screen.dart:218` e `calendar_screen.dart:1155` usam a certa.

**[Baixo] Label de campo excessivamente longo.** `'Professor (opcional — substitui o titular só nesta recorrência)'` (`turma_detail_screen.dart:603,921`) quebra em 2-3 linhas num diálogo de 460px — a explicação deveria ser texto de apoio, não o próprio rótulo.

**[Cosmético] Único empty-state com ponto final.** `'Nenhuma presença registrada.'` (`aluno_detail_screen.dart:719`) destoa dos outros 9 títulos equivalentes do produto, nenhum dos quais usa pontuação final.

### 3.2 Financeiro (Mensalidades / Caixa / Painel) — o módulo mais sensível

**[Crítico] Tabela "Evolução mensal" do Painel Financeiro sem empty state.**
`painel_financeiro_screen.dart` — `_EvolucaoTabela`/`_EvolucaoCardMobile` não checam `itens.isEmpty`; sem dado, renderiza só o cabeçalho da tabela sem nenhuma linha nem mensagem. Comparar com `relatorios_screen.dart:239`, que já faz exatamente esse check. **Toda academia piloto, no primeiro acesso a este módulo, sem nenhum histórico ainda, vai ver essa tela em branco** — confirmado também que é possível construir esse estado (uma academia nova sem lançamentos manuais e sem meses anteriores gerados cai exatamente aqui).

**[Alto] Divergência não explicada entre "Receita Recebida" (Painel) e "Receitas" (Caixa).**
Nomes diferentes para o que soa como o mesmo conceito, mas vêm de agregações distintas: `ResumoFinanceiro.receitaRecebida` (por competência de mensalidade) vs. `ResumoLancamentos.totalReceitas` (soma de lançamentos datados no mês, incluindo receita manual não ligada a mensalidade). Nada na UI avisa que os recortes são diferentes — se os números não baterem pro mesmo mês (plausível pelo desenho dos dois endpoints), o dono da academia vai achar que o sistema "não fecha as contas", não que são recortes diferentes por design.

**[Alto] "Retenção aproximada" promete uma explicação que não existe.**
`relatorios_screen.dart:169` — `deltaLabel: 'Aproximação — ver detalhe abaixo'`, confirmado visualmente truncado ("...ver detalhe ab...") e **sem nenhum conteúdo "abaixo" que explique a metodologia** em nenhum lugar da tela (a limitação real — sem histórico de status, é uma aproximação — só existe em comentário de código, nunca chega ao usuário).

**[Alto] "Inadimplência" sem destaque visual proporcional à gravidade.**
Confirmado visualmente: o card usa o mesmo tratamento neutro de "Despesas"; só "Saldo do mês" recebe destaque dourado (`highlight: true`). O design system hoje limita esse destaque a "no máximo uma métrica por tela" e não tem variante de urgência/alerta — dinheiro em atraso fica visualmente empatado com uma despesa qualquer.

**[Alto] Desconto/multa de mensalidade sem validação cruzada contra o valor base.**
`mensalidades_screen.dart`, `_descontoController`/`_multaController` só checam `>= 0`, nunca comparam desconto contra valor+multa. Um desconto maior que o valor gera `valorFinal` negativo, exibido cru na lista ("R$ -50,00").

**[Alto] Mensagens de validação podem vazar em inglês.**
Nenhum DTO financeiro revisado define `message:` customizado nos decorators (`@Min`, `@IsNumber`, `@IsEnum`...), e o `ValidationPipe` global não localiza mensagens. Como `mensagemErroApi()` repassa o `message` do backend verbatim, qualquer validação que escape do client-side aparece em inglês, misturada com o resto da UI em português — justamente no módulo mais sensível.

**[Médio] MetricCards financeiros sem ação/link.** Nenhum `MetricCard` tem `onTap` — "Inadimplência" seria candidato óbvio a levar direto pra lista de Mensalidades filtrada por atrasadas.

**[Baixo] Assimetria de recursos entre Caixa e as demais telas do módulo.** Caixa não tem os botões (desabilitados) "Ordenar"/"Exportar" que Mensalidades tem — paridade incompleta dentro do mesmo módulo.

**[Baixo] Sem caminho de Mensalidade → Caixa.** O Caixa já navega até a Mensalidade de origem; o inverso não existe.

**[Baixo] Tooltip do gráfico de linha (Relatórios) não identifica a série.** Mostra só o valor, colorido — o usuário precisa lembrar a cor da legenda acima.

**[Médio] Eixo X dos gráficos sem escala responsiva.** `interval: 1` fixo em `_ReceitaChart`/`_AlunosChart` — em desktop 1440px com 12 meses os rótulos couberam sem sobrepor (confirmado visualmente), mas o código não tem nenhuma lógica de densidade adaptativa; risco real em telas mais estreitas ou mobile não fica descartado pela leitura de código, só não observado no teste realizado.

**[Cosmético] Formatação `compactCurrency` do eixo Y** — primeiro uso no projeto, funcionou corretamente no teste visual realizado (formato "R$ X" plausível em pt_BR), sem achado negativo confirmado.

### 3.3 Alunos / Professores / Planos

**[Alto] "Remover" com estilo de perigo, mas efeito idêntico a "Inativar".**
Confirmado nas 3 telas (`aluno_detail_screen.dart`, `professor_detail_screen.dart`, `plano_detail_screen.dart`): o próprio diálogo do botão vermelho "Remover" avisa que é soft delete ("nada é apagado permanentemente") — o mesmo resultado do botão cinza "Inativar". A única diferença real é que "Remover" navega de volta à lista. Dois botões com nomes e cores de risco muito diferentes fazendo essencialmente a mesma coisa.

**[Alto] Validação de CPF só verifica "não vazio".**
Idêntico em Aluno e Professor — sem checksum, sem máscara, sem teclado numérico. O próprio Design System documenta `isValidCPF(v)` como exemplo de uso do `AppTextField`, mas essa função **nunca foi implementada**.

**[Alto] Risco de duplicidade ao re-tentar salvar após falha de upload de foto.**
`aluno_form_screen.dart`/`professor_form_screen.dart` — `create()`/`update()` roda, e só depois `uploadFoto()`, no mesmo `try`. Se o upload falhar, o erro mostrado sugere que nada foi salvo — mas o registro já existe. Se o usuário tentar salvar de novo na tela de "Novo X", um segundo `create()` é enviado.

**[Alto] Painel do Professor muito mais "vazio" que o do Aluno.**
4 de 6 seções são placeholder (Turmas, Financeiro, Arquivos, Histórico) contra 3 de 8 no Aluno. O modelo `Turma` já tem `professorId`/`professorNome` — o vínculo existe no domínio, só falta expor um filtro por professor em `ListTurmasQueryDto` (já documentado como pendência pequena na auditoria financeira anterior, docs/29).

**[Médio] "Financeiro" do Plano também placeholder**, apesar de `MensalidadesApi` já existir — falta só agregação por `planoId`.

**[Médio] Campo "Quantidade de aulas" (Plano) ambíguo** — não diz se é por semana, mês ou total do período (que varia por periodicidade).

**[Baixo] Tags de placeholder em formatos inconsistentes** — "EM BREVE" convive com "MÓDULO N · MSx" na mesma tela (Professor).

**[Baixo] "Ordem de exibição" (Plano) sem explicação de efeito.**

**[Cosmético] Paginação inconsistente dentro do próprio Aluno** — seção "Avaliações" sempre mostra `AppPagination`; Matrículas/Financeiro/Frequência só mostram quando há mais itens que a página.

### 3.4 Dashboard / Login / Navegação / Perfil (a primeira impressão)

**[Alto] Perfil: mensagem de erro com exceção crua na tela.**
`perfil_screen.dart:23-24` — `Text('Erro ao carregar perfil: $erro')` interpola o objeto `DioException` inteiro. O resto da própria tela usa `mensagemErroApi()` corretamente em outros dois pontos — só o estado de erro do carregamento inicial escapou.

**[Alto] Perfil: cargo exibido como valor técnico cru.**
`perfil_screen.dart:160-163` — `Text(perfil.role.wireValue, ...)` mostra literalmente `"ACADEMIA_ADMIN"`. **Confirmado visualmente**: a mesma informação aparece corretamente traduzida ("Administrador") no rodapé da sidebar da mesma tela — a inconsistência é visível lado a lado. `AppShell._cargoLabel()` já existe e faz essa tradução; só não é reaproveitada aqui.

**[Alto] Perfil: estrutura de tela duplicada.**
`perfil_screen.dart:19-20` — `PerfilScreen` (dentro do `ShellRoute`, já recebe `AppHeader`) monta seu **próprio** `Scaffold(appBar: AppBar(title: Text('Meu perfil')))`, único caso assim entre todas as telas do `ShellRoute`. Confirmado visualmente: o efeito não é uma barra duplicada óbvia (a segunda "Meu perfil" acaba parecendo só o título da página), mas o "título" da tela usa a fonte default do Material `AppBar`, visivelmente menor/mais fina que o `AppTypography.displayLarge` usado como H1 em toda outra tela do produto (compare "Bom dia, Admin" no Dashboard) — quebra de consistência tipográfica na própria tela de perfil do usuário.

**[Alto] Sidebar não filtrada por papel.**
`AppShell._destinos` é uma lista única usada para todo usuário autenticado, sem checar `Role`. Um professor ou recepcionista vê Financeiro/Planos/Relatórios na sidebar mesmo que o backend depois devolva 403 — cliques mortos, tela de erro em vez de navegação já recortada.

**[Alto] Design System Gallery acessível em produção, com exemplo enganoso.**
`/design-system` não tem nenhuma guarda além do login (comentário no código já assume o risco, mas nunca foi implementado). **Confirmado visualmente**: qualquer usuário autenticado consegue abrir o catálogo interno completo digitando a URL — fundo branco, terminologia de desenvolvedor ("displayLarge", "mono", "labelSmall"), completamente destoante do produto real. Pior: mostra como exemplo um item de sidebar "Financeiro" desabilitado e um `EmptyState.comingSoon` citando `"MÓDULO 3 · FINANCEIRO"` — só que Financeiro está implementado e em uso há tempos. Um dono de academia curioso que caia aqui pode achar que um módulo que ele já usa todo dia "ainda não existe".

**[Médio] Tablet (768px) cai no layout de desktop inteiro.**
`AppBreakpoints` documenta 3 faixas (mobile/tablet/desktop) mas `AppShell` só checa `isMobile`. **Confirmado visualmente**: um tablet em retrato recebe a sidebar fixa de 260px + `AppHeader` completo, exatamente como um desktop de 1440px, espremendo o conteúdo real em ~500px de largura útil.

**[Médio] Contraste insuficiente do token `textFaint`.**
`#5C5C58` sobre `#0B0B0B` mede ≈2.9:1, abaixo do mínimo WCAG AA (4.5:1). Usado em conteúdo real (rótulos "Hoje"/data na Agenda da semana, seções da sidebar, timestamp de notificação), não só decorativo.

**[Médio] Cards "Alunos novos"/"Aniversariantes" do Dashboard não são clicáveis**, inconsistente com as duas seções acima na mesma tela (Alertas financeiros, Agenda da semana) que já têm `onTap`.

**[Médio] Sem tela de "Configurações da academia".**
Não existe hoje nenhuma tela em `admin_web` pra isso — confirmado por busca no código inteiro. O backend já tem `AcademiaConfiguracao` (logo, cores, redes sociais, PIX, horário de funcionamento) mas só é editável via um painel `SYSTEM_ADMIN` que a própria academia não acessa. Um dono de academia não tem, hoje, nenhuma forma de configurar a própria marca ou chave PIX pelo próprio painel.

**[Médio] Sem fluxo de "esqueci minha senha".** Confirmado por busca no código — não existe. Trocar senha exige saber a senha atual.

**[Médio] Mensagem de erro de login genérica demais.** Fallback `'Não foi possível entrar. Verifique suas credenciais.'` (`login_screen.dart:56-58`) aparece inclusive para erro de rede/timeout/servidor fora do ar, sugerindo erroneamente que a senha está errada.

**[Médio] Troca de senha desloga sem nenhuma confirmação de sucesso.** `_trocarSenha()` limpa a sessão e manda pro login imediatamente após sucesso, sem nenhuma mensagem — parece falha, não sucesso.

**[Médio] Uso de `SnackBar` pra erro de formulário no Perfil, contrariando a própria regra documentada do Design System** ("AppFormErrorBanner — nunca SnackBar", conforme a própria galeria interna).

**[Baixo] "Usuários do sistema" como indicador do Dashboard** — única métrica das 4 que não ajuda a administrar o negócio (contagem de contas, não dado operacional).

**[Baixo/Cosmético] Login não reaproveita o Design System.** `TextFormField`/`FilledButton` crus em vez de `AppTextField`/`AppButton`. **Confirmado visualmente**: o resultado não parece visivelmente quebrado (a tela é limpa, funcional, na paleta certa), mas é a única tela do produto com esse desvio de arquitetura — qualquer ajuste futuro de estilo de campo/botão não vai refletir automaticamente aqui.

---

## 4. Classificação (todos os achados, por severidade)

| Severidade | Qtde | Definição usada nesta revisão |
|---|---|---|
| **Crítico** | 2 | Bloqueia ou quebra um fluxo essencial do negócio, ou expõe risco real sem o usuário perceber |
| **Alto** | 15 | Gera confusão significativa, retrabalho ou prejudica a confiança/percepção profissional diretamente |
| **Médio** | 11 | Perceptível e vale corrigir, mas contornável ou situacional |
| **Baixo** | 8 | Pequena fricção ou inconsistência, não impede a tarefa |
| **Cosmético** | 4 | Só estética/detalhe textual, zero impacto funcional |

**Crítico**: (1) presença não marcável no dia da aula; (2) Painel Financeiro sem empty state na evolução mensal.

**Alto**: opção "Não marcada" morta; sem ação em lote de presença; divergência Receita Recebida/Receitas; "ver detalhe abaixo" inexistente; Inadimplência sem destaque; desconto/multa sem validação cruzada; mensagens de validação em inglês; Remover≈Inativar (Aluno/Professor/Plano); CPF sem validação real; risco de duplicidade no upload de foto; Painel do Professor muito vazio; Perfil com exceção crua; Perfil com cargo cru; Perfil com estrutura duplicada; Sidebar sem filtro de papel; Design System Gallery exposta.

*(nota: a lista acima soma 16 itens de texto, mas dois — "Remover≈Inativar" e os 3 achados de Perfil — são contados como 1 e 3 ocorrências respectivamente na tabela para refletir amplitude; ver detalhamento completo na seção 3)*

**Médio**: vagas Turma vs ocupação Aula; MetricCards sem ação; eixo X sem escala responsiva; "Financeiro" do Plano placeholder; "Quantidade de aulas" ambíguo; tablet sem tratamento; contraste `textFaint`; cards do Dashboard não clicáveis; sem tela de Configurações; sem "esqueci senha"; mensagem de erro de login genérica; troca de senha sem confirmação de sucesso; SnackBar em vez de AppFormErrorBanner no Perfil.

**Baixo**: empty state de Reposições sem contexto de filtro; ações de aula passada sem bloqueio; label de campo longo demais; tags de placeholder inconsistentes; "Ordem de exibição" sem explicação; assimetria Caixa vs outras telas; sem link Mensalidade→Caixa; tooltip de gráfico sem série; "Usuários do sistema" como indicador; textos "em breve" residuais em Ordenar/Exportar.

**Cosmético**: "Ilimitado"/"Ilimitada"; ponto final solitário em empty state; "Avaliações" vs "Avaliação física"; paginação inconsistente em Aluno; login não reaproveita design system; formatação de moeda compacta (sem achado negativo, só não 100% verificada).

---

## 5. Melhorias rápidas (Quick Wins)

Baixíssimo esforço, alto retorno de percepção profissional — todas de 1 arquivo, sem migration:

1. Perfil: trocar `role.wireValue` por `AppShell._cargoLabel()` (ou extrair essa função pra um local compartilhado).
2. Perfil: trocar `Text('Erro ao carregar perfil: $erro')` por `mensagemErroApi()`, já usado no resto da mesma tela.
3. Perfil: remover o `Scaffold`/`AppBar` próprios — devolver só o conteúdo, como toda outra tela do `ShellRoute`.
4. Painel Financeiro: adicionar o mesmo check `itens.isEmpty` que `relatorios_screen.dart` já usa, com `EmptyState` equivalente.
5. Gatear `/design-system` atrás de `kDebugMode` (ou remover do `GoRouter` em build de release) — resolve o vazamento de uma vez.
6. Corrigir "Ilimitado" → "Ilimitada" em `turma_form_screen.dart:229`.
7. Padronizar pontuação dos empty states (remover o ponto final de `aluno_detail_screen.dart:719`).
8. Renomear card "Avaliações" → "Avaliação física" em `aluno_detail_screen.dart:857`.
9. Adicionar `onTap` nos tiles "Alunos novos"/"Aniversariantes" do Dashboard (copiar o padrão já usado em `_AlertasFinanceirosSection`).
10. Adicionar mensagem de sucesso antes do logout em `_trocarSenha()`.

---

## 6. Melhorias recomendadas para versão 1.1

Esforço médio, valor real, não bloqueiam o piloto mas devem entrar logo depois:

1. Corrigir `_aulaRealizada()` para considerar `horaInicio`, não só a data — permitir marcar presença no mesmo dia.
2. Ação em lote "marcar todos como presentes" na tela de frequência da aula.
3. Remover a opção "Não marcada" do seletor de presença, ou implementar de verdade a operação de desmarcar no backend.
4. Filtrar `AppShell._destinos` por `Role` do usuário logado.
5. Adicionar validação cruzada de desconto/multa em Mensalidade (`desconto + multa` não pode gerar `valorFinal` negativo), client-side e no backend.
6. Dar destaque visual de alerta à "Inadimplência" no Painel Financeiro (nova variante de tom no `MetricCard`, ou mover pro topo).
7. Implementar o "detalhe" da Retenção Aproximada prometido em Relatórios, ou remover a promessa do `deltaLabel`.
8. Esclarecer a relação entre "Receita Recebida" (Painel) e "Receitas" (Caixa) — renomear pra deixar o recorte explícito, ou adicionar nota explicando a diferença.
9. Corrigir o fluxo de criação de Aluno/Professor para não arriscar duplicidade quando o upload de foto falha isoladamente.
10. Adicionar validação de CPF de verdade (checksum + máscara) em Aluno/Professor.
11. Adicionar uma tela mínima de "Configurações da academia" (branding, PIX, horário) consumindo o `AcademiaConfiguracao` que o backend já expõe.
12. Adicionar fluxo de "esqueci minha senha".
13. Revisar todos os DTOs financeiros pra garantir mensagem de validação em PT-BR (`message:` customizado nos decorators mais usados).
14. Reavaliar a redundância "Remover" vs "Inativar" em Aluno/Professor/Plano — considerar unificar, ou diferenciar de verdade o efeito de cada um.

---

## 7. Melhorias para longo prazo

1. Expor filtro por `professorId` em `ListTurmasQueryDto` e agregação por `planoId` em Mensalidades, para finalmente tirar os placeholders de "Turmas"/"Financeiro" do Professor e "Financeiro" do Plano.
2. Decidir o destino de `Plano.quantidadeAulas` — hoje puramente informativo, sem nenhum enforcement em Agenda.
3. Módulos ainda no roadmap (Treinos, Arquivos, Histórico/auditoria por entidade) — sem alteração recomendada agora, apenas mantidos no radar.
4. Reescrever a tela de Login sobre o Design System (`AppTextField`/`AppButton`), unificando 100% do produto sob a mesma base de componentes.
5. Auditoria de acessibilidade completa (contraste de todos os tokens, não só `textFaint`; navegação por teclado; leitores de tela).
6. Tratamento real do breakpoint de tablet (sidebar colapsável/compacta entre 600-1024px, não o mesmo layout de desktop).
7. Escala responsiva de verdade para os gráficos de Relatórios (densidade de rótulo do eixo X adaptativa à largura disponível e ao tamanho da janela selecionada).

---

## 8. Checklist final de release

### Bloqueadores — resolver antes do piloto
- [ ] Corrigir marcação de presença no dia da própria aula (`_aulaRealizada`)
- [ ] Adicionar empty state na "Evolução mensal" do Painel Financeiro
- [ ] Investigar e esclarecer (ou corrigir) a divergência entre "Receita Recebida" e "Receitas"
- [ ] Corrigir a tela de Perfil: mensagem de erro crua, cargo cru, estrutura de Scaffold duplicada
- [ ] Gatear ou remover o acesso de produção à rota `/design-system`

### Fortemente recomendado antes do piloto
- [ ] Filtrar a sidebar por papel (Role)
- [ ] Corrigir o risco de duplicidade no upload de foto (Aluno/Professor)
- [ ] Adicionar validação de CPF real
- [ ] Garantir que nenhuma mensagem de validação escape em inglês
- [ ] Resolver a ambiguidade "Remover" vs "Inativar"
- [ ] Adicionar validação cruzada de desconto/multa em Mensalidade
- [ ] Dar destaque visual condizente à Inadimplência

### Pode esperar para v1.1 (documentado, não esquecido)
- [ ] Ação em lote de presença + opção "Não marcada" morta
- [ ] Tela de Configurações da academia
- [ ] Fluxo de "esqueci minha senha"
- [ ] Tratamento real de breakpoint tablet
- [ ] Placeholders remanescentes (Treinos/Arquivos/Histórico do Aluno; Turmas/Financeiro/Arquivos/Histórico do Professor; Financeiro do Plano)
- [ ] "Ver detalhe abaixo" da Retenção Aproximada
- [ ] Demais achados Baixo/Cosmético da seção 3

---

## 9. Conclusão

O SaaSGym está estruturalmente pronto para um piloto — os fluxos centrais (cadastro de aluno/professor/plano, matrícula, mensalidade, agenda, avaliação física, relatório) funcionam, são bem desenhados na maioria das telas, e já incorporam correções estruturais reais feitas antes desta revisão (Sprint de Integridade Financeira). O produto não "parece incompleto" no sentido amplo — parece, em vários pontos específicos e concentrados, **ainda não polido**: um bug real na ação mais repetida do dia a dia de um professor, um módulo financeiro que mostra tela em branco pro primeiro acesso de uma academia nova, e uma tela de Perfil — a primeira coisa que qualquer usuário clica por curiosidade — com três problemas visíveis ao mesmo tempo.

Recomendação: resolver os 2 itens Críticos e o bloco "fortemente recomendado" desta lista antes de abrir para a academia piloto. Os itens de Médio/Baixo/Cosmético compõem um backlog de v1.1 saudável — não são sinal de projeto malfeito, são o resultado esperado de uma revisão deliberadamente rigorosa, pedida exatamente para não deixar nenhuma dessas bordas passar despercebida no primeiro contato com um cliente real.
