# 32 — Auditoria: Ciclo de Vida do Aluno

Auditoria pura (sem alteração de código) — objetivo: garantir que um aluno arquivado (`status = INATIVO`) ou removido (`deletedAt` preenchido) nunca continue aparecendo em módulos operacionais como se ainda fosse um participante ativo.

## Metodologia

Leitura direta do backend (NestJS/Prisma) e do frontend (`admin_web`) em 11 áreas, sempre respondendo cinco perguntas fixas: o aluno continua aparecendo depois de arquivado/removido? o comportamento é o esperado? existe filtro por `deletedAt`/`status`? existe relacionamento órfão? o que precisa ser corrigido?

Duas coisas precisam ficar claras antes dos achados por módulo, porque explicam **por que** o mesmo padrão de bug se repete em quase todo lugar:

### 1. `Aluno.status` e `Aluno.deletedAt` são dois campos independentes

- `status` (`UserStatus`: `ATIVO`/`INATIVO`) — usado quando o aluno sai da academia de verdade ("Inativar" na UI). É reversível ("Reativar").
- `deletedAt` — soft delete, reservado a corrigir um cadastro feito por engano ("Remover" na UI). Sem botão de reversão na UI hoje.

São ortogonais: um aluno pode estar `status: ATIVO` e `deletedAt: <data>` (removido por engano, mas nunca "reativado" via inativar/reativar), ou `status: INATIVO` e `deletedAt: null` (saiu da academia, mas continua um cadastro válido e pesquisável).

### 2. Não existe filtro automático de soft-delete — cada query é responsável por si

A extensão multi-tenant do Prisma (`backend/src/common/prisma/prisma-tenant.extension.ts`) só injeta `academiaId` automaticamente em toda operação — nunca `deletedAt`. Isso é uma decisão documentada explicitamente em `alunos.service.ts:19-22` ("soft delete filtrado aqui no service... decisão explícita de não empilhar essa responsabilidade na extensão do Prisma"). Consequência prática: **cada leitura precisa lembrar de filtrar `deletedAt: null` manualmente**, e isso nunca se propaga para relações trazidas via `include` — um `include: { aluno: {...} }` sempre traz o aluno como está, mesmo removido/arquivado, porque o Prisma não reaplica o hook da extensão dentro de um `include`.

### 3. A causa raiz real: arquivar/remover um Aluno nunca propaga pra mais nada

`AlunosService.updateStatus()` e `AlunosService.remove()` (`backend/src/modules/alunos/alunos.service.ts:130-168`) só tocam a própria linha do Aluno:

```ts
async remove(id: string, meta: RequestMetadata = {}): Promise<void> {
  await this.findOrThrow(id);
  const academiaId = this.tenantContext.getAcademiaId() as string;
  await this.prisma.forTenant().aluno.update({ where: { id }, data: { deletedAt: new Date() } });
  await this.auditService.record({ action: AuditAction.ALUNO_DELETED, ... });
}
```

Nenhuma checagem de relacionamento, nenhum cascade. Contraste direto com `PlanosService.remove()` (Sprint de Integridade Financeira, docs/29), que **bloqueia** a remoção se existir matrícula vinculada. Para Aluno, o mesmo tipo de proteção nunca foi implementado — um aluno pode ser arquivado ou removido com uma Matrícula `ATIVA`, inscrições de Turma ativas e mensalidades pendentes, sem nenhum aviso.

Como nada cascateia, os registros filhos (`Matricula`, `TurmaAluno`, `SolicitacaoReposicao`) continuam com seu próprio `status` inalterado, e cada consulta que confia nesse status filho (em vez de checar o `Aluno` de novo) segue tratando o aluno como participante ativo. **Esse é o padrão que se repete em quase todos os achados abaixo.**

---

## Achados por módulo

### 1. Turmas (inscrição — `TurmaAluno`)

1. **Continua aparecendo?** Sim. `TurmaAlunosService.list()` (`turma-alunos.service.ts:68-72`) filtra só `TurmaAluno.deletedAt: null` — nenhum filtro em `Aluno.status`/`Aluno.deletedAt`. Um aluno arquivado ou removido continua listado como "matriculado" na turma, com nome via `include`.
2. **Correto?** Não. Uma turma não deveria mostrar como "matriculado" alguém que já saiu da academia.
3. **Filtro por deletedAt/status?** Só em `create()` — `garantirAlunoExiste` (`turma-alunos.service.ts:140-145`) checa `deletedAt: null`, mas nunca `status`. Ou seja: bloqueia inscrever um aluno removido, mas **não** bloqueia inscrever um aluno arquivado.
4. **Relacionamento órfão?** Sim — `TurmaAluno.status: ATIVO` sobrevive indefinidamente a um Aluno arquivado/removido, porque nada cascateia.
5. **O que corrigir?** `list()` precisa excluir alunos arquivados/removidos (ou, no mínimo, sinalizar visualmente); `create()`/`garantirAlunoElegivel` precisa checar `Aluno.status = ATIVO` também, não só `Matricula.status = ATIVA`.

### 2. Agenda (geração de Aulas futuras + ocupação)

1. **Continua aparecendo?** Sim, de duas formas. (a) `AulasService.gerar()` (`aulas.service.ts:74-76`) busca `TurmaAluno` com `status: ATIVO, deletedAt: null` — sem checar o Aluno — e usa isso para **criar novas linhas de `AulaAluno` em aulas futuras**. Um aluno arquivado hoje continua sendo inscrito em toda aula nova gerada daqui pra frente. (b) O contador `totalAlunos` (`aulas.service.ts:20,25,390`) usa `_count: { select: { alunos: true } }` **sem nenhum `where`** — nem `deletedAt: null` — diferente do campo irmão `totalReposicoes`, que filtra corretamente (`alunos: { where: { tipo: REPOSICAO, deletedAt: null } }`, linha 25).
2. **Correto?** Não, nos dois pontos. Ocupação/capacidade é um número operacional (usado por `calendar_screen.dart` pra decidir se a turma está cheia) — não pode contar quem não é mais aluno ativo.
3. **Filtro por deletedAt/status?** `gerar()`: nenhum (nem em `TurmaAluno`→`Aluno`, nem propagado). `totalAlunos`: nenhum, nem o `deletedAt` básico.
4. **Relacionamento órfão?** Sim — é o achado de maior severidade da auditoria: um aluno arquivado/removido continua sendo **ativamente inscrito em aulas que ainda vão acontecer**, não é só um resíduo histórico.
5. **O que corrigir?** `gerar()` precisa filtrar também `aluno: { status: ATIVO, deletedAt: null }` na busca de `TurmaAluno` elegíveis. O `_count` de `totalAlunos` precisa do mesmo filtro que `totalReposicoes` já tem (Prisma suporta `where` aninhado em `_count.select`, incluindo por relação — não é uma limitação técnica, é só um `where` que faltou).

### 3. Frequência (`AulaAluno` — presença)

1. **Continua aparecendo?** Sim, em `listPorAula()`/`listPorAluno()` (`aula-alunos.service.ts:48-58,60-93`) — filtram só `AulaAluno.deletedAt: null`, nunca o status do Aluno.
2. **Correto?** Depende do contexto, e aqui está a nuance real: pra uma aula **já realizada**, mostrar a presença de alguém que hoje está arquivado é correto — é fato histórico, documentado explicitamente como tal no próprio código (`aula-alunos.service.ts:27-39`, "Frequência é fato histórico"). Pra uma aula **futura**, é incorreto — o aluno não deveria nem estar na lista (ver achado #2, é lá que a raiz do problema está, não aqui).
3. **Filtro por deletedAt/status?** Só `deletedAt` da própria `AulaAluno`, nunca do Aluno.
4. **Relacionamento órfão?** Não neste módulo especificamente — ele só reflete fielmente o que a geração de aulas (#2) e a aprovação de reposição (#10) colocaram lá.
5. **O que corrigir?** Nada estrutural aqui — Frequência está correta para seu propósito de registro histórico. A correção real é upstream (#2 e #10); o único ajuste cabível aqui é cosmético (sinalizar visualmente, ao registrar presença numa aula futura, se algum aluno da lista está arquivado/removido).

### 4. Matrículas

1. **Continua aparecendo?** Sim. `MatriculasService.list()`/detalhe (`matriculas.service.ts:160-192`) filtra só `Matricula.deletedAt: null` — o aluno vem via `include`, sem filtro de `deletedAt`/`status` nenhum. Uma matrícula de um aluno removido/arquivado aparece normalmente na lista, indistinguível de uma matrícula de aluno ativo.
2. **Correto?** Parcialmente. Para matrículas em status terminal (`CANCELADA`/`ENCERRADA`) é aceitável manter no histórico. O problema real é que **nada impede uma Matrícula `ATIVA` de sobreviver a um Aluno arquivado/removido** — ver #4 abaixo.
3. **Filtro por deletedAt/status?** `create()` (`matriculas.service.ts:69-75`) bloqueia criar matrícula pra aluno removido (`deletedAt: null` no `findFirst`), mas **não bloqueia** criar pra aluno arquivado (`status` nunca é checado).
4. **Relacionamento órfão?** Sim, e é o pivô de praticamente todos os outros achados: como `AlunosService` nunca cascateia, uma Matrícula pode ficar `ATIVA` indefinidamente presa a um Aluno arquivado/removido, e é exatamente essa Matrícula `ATIVA` "fantasma" que permite `TurmaAlunosService.garantirAlunoElegivel()` (#1) e `MensalidadesService.gerar()` (#5) continuarem tratando o aluno como ativo.
5. **O que corrigir?** `create()` precisa checar `status: ATIVO` além de `deletedAt: null`. E — decisão de produto a confirmar com você — considerar se `AlunosService.remove()`/`updateStatus()` deveriam **bloquear** (como `PlanosService.remove()` já faz) ou **cascatear** (trancar/cancelar a matrícula automaticamente) quando existe uma Matrícula `ATIVA` vinculada.

### 5. Mensalidades

1. **Continua aparecendo?** Sim, de um jeito ativo, não só passivo: `MensalidadesService.gerar()` (`mensalidades.service.ts:78-86`) elegibiliza pela `Matricula.status = ATIVA`, nunca pelo `Aluno.status`. Como a Matrícula não é cancelada quando o aluno é arquivado (achado #4), **`gerar()` continua criando cobranças novas, mês a mês, pra um aluno que a recepção já considera "fora"**.
2. **Correto?** Não, para geração de cobrança nova. É correto para o histórico (`list()`, que não filtra por status do aluno — e não deveria, é contabilidade) — a distinção importa: mostrar uma mensalidade paga por alguém que já saiu está certo; gerar uma mensalidade **nova** pra alguém que já saiu está errado.
3. **Filtro por deletedAt/status?** `gerar()`: nenhum filtro em `Aluno`. `list()`/histórico: nenhum, e está correto assim (contabilidade não deve sumir).
4. **Relacionamento órfão?** Sim — mensalidades novas continuam nascendo de uma Matrícula "fantasma" (ver #4).
5. **O que corrigir?** A correção de fundo é a mesma do achado #4 (Matrícula não devia ficar `ATIVA` presa a um Aluno inativo) — resolvendo isso na origem, `gerar()` já para de gerar cobrança nova automaticamente, sem precisar de uma checagem extra aqui.

### 6. Caixa (Lançamentos)

1. **Continua aparecendo?** Não aplicável diretamente — `Lancamento` **não tem campo `alunoId`** (confirmado, zero ocorrências no módulo). A única ligação com Aluno é indireta, via `Mensalidade.alunoId` quando um lançamento nasce de um pagamento (`marcarPaga()`).
2. **Correto?** Sim, dado que não há vínculo direto.
3. **Filtro por deletedAt/status?** N/A.
4. **Relacionamento órfão?** Não.
5. **O que corrigir?** Nada neste módulo especificamente.

### 7. Dashboard

Aqui a auditoria confirmou um bug real e concreto, não só um risco teórico.

1. **Continua aparecendo?** Sim, em 3 dos 5 campos que leem `Aluno`:
   - `aniversariantes` (`dashboard.service.ts:116-124`, SQL bruto) — filtra `deletedAt IS NULL`, **mas não `status = 'ATIVO'`**. Um aluno arquivado com aniversário no mês aparece no widget "Aniversariantes".
   - `novosAlunosMes`/`alunosNovos` (`dashboard.service.ts:69-79`) — mesmo padrão: filtra `deletedAt`, não `status`. Um aluno cadastrado e arquivado no mesmo mês continua contado/listado como "novo".
   - `alunosAtivos` (`dashboard.service.ts:67`) e `totalAlunos` (linha 66) estão corretos (o primeiro filtra os dois campos; o segundo é "total geral", que por definição não deveria filtrar `status` mesmo).
2. **Correto?** Não, para os três primeiros — são apresentados como itens acionáveis do dia a dia, não como histórico.
3. **Filtro por deletedAt/status?** `deletedAt` sim em todos; `status` só em `alunosAtivos`.
4. **Relacionamento órfão?** Não é bem um "órfão", é uma omissão de filtro direta.
5. **O que corrigir?** Adicionar `status: ATIVO` nas 3 queries (`aniversariantes`, `novosAlunosMes`, `alunosNovos`). Correção pequena e isolada.

Achado adicional (fora dos 5 campos centrais, mas no mesmo módulo): os alertas financeiros do Dashboard (`proximosVencimentos`, `inadimplencia`, `receitaPrevista`, em `mensalidades.service.ts`/`dashboard-financeiro`) herdam o mesmo problema do achado #5 — mensalidade/matrícula de aluno arquivado aparece como cobrança "ativa" nos alertas.

### 8. Relatórios

1. **Continua aparecendo?** Não, na prática — `alunosAtivosHoje` (`relatorios.service.ts:63`) filtra `deletedAt` **e** `status` corretamente. `cancelamentosPeriodo`/`novosAlunos`/`cancelamentos` mensais são todos derivados de `Matricula` (status `CANCELADA`, `matriculaAnteriorId`), nunca de `Aluno` diretamente — não há como um aluno arquivado "vazar" nessas métricas, porque elas nem olham pro `Aluno.status`.
2. **Correto?** Sim, este é o módulo mais bem comportado de toda a auditoria.
3. **Filtro por deletedAt/status?** Sim, onde se aplica.
4. **Relacionamento órfão?** Não.
5. **O que corrigir?** Nada.

### 9. Pesquisa global

1. **Continua aparecendo?** Não se aplica — **a busca não existe de verdade hoje**. O campo "Buscar aluno, professor..." no cabeçalho (`app_header.dart`) é decorativo: não é um `TextField`, não tem `onChanged`/`onSubmitted`, e ao clicar abre um popover "Ainda não disponível nesta versão do SaaSGym" (confirmado no próprio comentário do código: "Busca continua sem funcionalidade real... propositalmente 'burra'").
2. **Correto?** N/A — não há comportamento pra avaliar.
3. **Filtro por deletedAt/status?** N/A.
4. **Relacionamento órfão?** Não.
5. **O que corrigir?** Nada agora. Alerta pra quando a busca for implementada de verdade: o candidato óbvio de backend (`AlunosService.list()`) já filtra `deletedAt: null` sempre, mas `status` é opcional (só filtra se o chamador passar `status=...` explicitamente) — quem implementar a busca precisa lembrar de passar `status: ATIVO`, ou herda o mesmo bug do Dashboard.

### 10. Reposições

1. **Continua aparecendo?** Sim. `SolicitacoesReposicaoService.list()` (`solicitacoes-reposicao.service.ts:88-95`) não filtra o aluno solicitante de forma alguma. Uma reposição pendente de um aluno já arquivado/removido continua na fila padrão que a recepção vê.
2. **Correto?** Não.
3. **Filtro por deletedAt/status?** Nenhum, em `list()`, `criar()` ou `aprovar()`.
4. **Relacionamento órfão?** Sim, e com efeito prático: `aprovar()` (`solicitacoes-reposicao.service.ts:116-176`) não checa o status do aluno antes de criar uma nova `AulaAluno(REPOSICAO)` numa aula **futura** — ou seja, a recepção pode, sem saber, aprovar uma reposição pra alguém que já não é mais aluno, alimentando de novo o achado #2 (inflando ocupação de aula futura).
5. **O que corrigir?** `list()` deveria permitir filtrar/sinalizar solicitações de alunos arquivados/removidos; `aprovar()` deveria bloquear (ou pelo menos avisar) quando o aluno solicitante não está mais `ATIVO`.

### 11. Notificações

1. **Continua aparecendo?** Não é uma pergunta que se aplica da mesma forma — `Notificacao` **não tem `alunoId`** como chave estrangeira. O nome do aluno é gravado como texto puro na hora da criação (ex.: `` `${solicitacao.aluno.nome} solicitou reposição...` ``, em `solicitacoes-reposicao.service.ts`), nunca resolvido de novo na leitura.
2. **Correto?** Sim — esse é exatamente o padrão "seguro" (snapshot de texto, sem FK pra resolver depois).
3. **Filtro por deletedAt/status?** N/A — não há junção com `Aluno` na leitura.
4. **Relacionamento órfão?** Não — não há nada pra orfanizar.
5. **O que corrigir?** Nada.

---

## Inventário de relacionamentos que ficam "soltos" quando o Aluno é arquivado/removido

| Registro filho | Campo que deveria mudar, mas não muda | Efeito prático |
|---|---|---|
| `Matricula` (status `ATIVA`) | Nada — continua `ATIVA` | Alimenta geração de mensalidade nova e elegibilidade de turma |
| `TurmaAluno` (status `ATIVO`) | Nada — continua `ATIVO` | Aluno segue sendo inscrito em toda aula nova gerada |
| `AulaAluno` em aulas futuras | Nada — segue sendo criado pela geração | Ocupação inflada, presença registrável pra quem já saiu |
| `SolicitacaoReposicao` (status `PENDENTE`) | Nada — segue na fila | Pode ser aprovada, criando mais `AulaAluno` futuro |

`Mensalidade` (histórico), `Lancamento`, `AvaliacaoFisica` e `Notificacao` não entram nesta tabela de propósito — são registros **factuais/históricos**, e continuar mostrando-os mesmo após o aluno ser arquivado/removido é o comportamento correto, não um bug.

## Classificação por severidade

**Alto** (afeta operação futura, não só exibição de dado antigo):
- Geração de Aulas futuras continua inscrevendo aluno arquivado/removido (`aulas.service.ts:74-76`)
- `totalAlunos` (ocupação) sem filtro nenhum, nem `deletedAt` básico (`aulas.service.ts:20`)
- `MensalidadesService.gerar()` continua criando cobrança nova pra aluno arquivado (`mensalidades.service.ts:78-86`)
- Aprovação de reposição não checa status do aluno antes de criar `AulaAluno` futuro (`solicitacoes-reposicao.service.ts:116-176`)
- Nenhuma checagem de relacionamento em `AlunosService.remove()`/`updateStatus()` (causa raiz)

**Médio** (exibição incorreta em telas operacionais do dia a dia, sem gerar novo dado):
- Dashboard: `aniversariantes`, `novosAlunosMes`, `alunosNovos` sem filtro de `status`
- `TurmaAlunosService.list()` mostra aluno arquivado/removido como "matriculado"
- `MatriculasService.create()`/`TurmaAlunosService.create()` não bloqueiam aluno arquivado (só removido)
- `SolicitacoesReposicaoService.list()` sem filtro de status do aluno

**Baixo** (histórico, comportamento já correto ou risco só latente):
- Frequência histórica, Mensalidades/histórico, Relatórios, Notificações, Caixa, Pesquisa global (nem existe ainda)

## Plano de correção proposto (pequenos commits, um de cada vez)

Ordem sugerida — dos achados mais isolados/seguros pros que tocam mais módulos, terminando na decisão de produto que precisa da sua confirmação antes de eu implementar:

1. **Dashboard: adicionar `status: ATIVO` em `aniversariantes`, `novosAlunosMes`, `alunosNovos`.** 3 queries, arquivo único, zero ambiguidade — mesmo padrão que `alunosAtivos` já usa ao lado.
2. **`totalAlunos` (ocupação de Aula): filtrar `deletedAt: null` no `_count`, igual já é feito em `totalReposicoes`.** Isolado, sem tocar em regra de negócio nova — só completa um filtro que faltou.
3. **`TurmaAlunosService.list()`: excluir (ou sinalizar) alunos arquivados/removidos da lista de matriculados.** Um arquivo, decisão de UI a confirmar (excluir da lista vs. mostrar com uma badge "Inativo").
4. **`SolicitacoesReposicaoService.list()`: mesmo tratamento — excluir/sinalizar solicitações de aluno arquivado/removido.**
5. **Bloquear a criação de novo vínculo pra aluno arquivado (não só removido)**: `MatriculasService.create()`, `TurmaAlunosService.create()` — adicionar `status: ATIVO` nas checagens que hoje só fazem `deletedAt: null`.
6. **`AulasService.gerar()`: parar de inscrever aluno arquivado/removido em aulas novas** — adicionar filtro de `Aluno.status`/`deletedAt` na busca de `TurmaAluno` elegíveis.
7. **`SolicitacoesReposicaoService.aprovar()`: bloquear aprovação pra aluno arquivado/removido** (evita a última porta de entrada de `AulaAluno` futuro pra aluno inativo).
8. **Decisão de produto, antes de eu tocar em código** — o item que resolveria a causa raiz de vez: quando um Aluno é arquivado ou removido, o que deve acontecer com a Matrícula `ATIVA` dele?
   - **Opção A — bloquear**, igual `PlanosService.remove()` já faz: impedir arquivar/remover um aluno com Matrícula `ATIVA` (staff precisa trancar/cancelar a matrícula primeiro).
   - **Opção B — cascatear**: arquivar/remover o aluno automaticamente tranca ou cancela a(s) Matrícula(s) `ATIVA` dele.
   - Resolvendo isso, os itens 5 e 6 acima passam a ser redundantes (a Matrícula nunca mais fica "fantasma"), mas ainda valem como segunda camada de proteção.

Cada item acima sai como um commit isolado, compilando e com teste — nada de pacote único. Não vou implementar nada disso até você aprovar (e me dizer sua preferência no item 8, já que muda o comportamento de negócio, não é só um filtro faltando).
