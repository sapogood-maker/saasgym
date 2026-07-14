# Módulo 4 — Agenda: análise de domínio (pré-implementação)

Escrito ao final do Módulo 3 (Financeiro), antes de qualquer código do Módulo 4, seguindo o mesmo fluxo já usado em `docs/16-modulo-2-matriculas-analise.md` e `docs/17-modulo-3-financeiro-analise.md`: analisar → propor → aprovar → só então implementar — aplicado ao modelo de domínio, não a uma tela.

Agenda é o módulo que fecha o ciclo operacional diário do ERP: até aqui o sistema sabe *quem* está matriculado (`Matricula`) e *quanto/quando* deveria pagar (`Mensalidade`), mas não existe nenhum registro de *quando o aluno efetivamente frequenta a academia*. É também o módulo com mais peças novas do projeto até agora — por isso esta análise é mais longa que as anteriores, e por isso nenhuma decisão aqui está implementada ainda.

## 1. Entendimento do domínio

### O papel da Agenda no ERP

- **Operacional**: é a tela que a recepção/professor mais olha no dia a dia — "quem vem hoje", "que horas", "quem substitui". Nenhum dos módulos anteriores tem esse ritmo diário; Alunos/Professores/Planos/Matrículas/Financeiro são consultados semanal ou mensalmente, Agenda é consultada várias vezes ao dia.
- **Integração com Academia**: toda entidade nova é tenant-scoped (`academiaId`), mesmo padrão de tudo até aqui. `AcademiaConfiguracao.horarioFuncionamento` (Sprint 2, campo `Json?` já existente, nunca consumido) é uma integração natural — Agenda pode ser o primeiro módulo a de fato ler esse campo (ex.: alertar se uma Turma é criada fora do horário de funcionamento). **Não obrigatório no MVP** — ver seção 7.
- **Integração com Professores**: `Turma`/`Recorrencia`/`Aula` referenciam `Professor` (titular + substituto pontual). `Professor` **não muda de schema** nesta análise — nenhum campo novo é adicionado a ele.
- **Integração com Alunos**: frequência (`AulaAluno.presente`) e matrícula em turma (`TurmaAluno`) são a fonte de dois blocos que a tela de detalhe do aluno já reserva hoje (`AlunoDetailScreen`, seções "Frequência" e, indiretamente, "Turmas" no professor) — ver "Ponta solta" ao final.
- **Integração com Matrículas**: elegibilidade para entrar numa `Turma` depende de o aluno ter uma `Matricula` `ATIVA` — mesma intenção já registrada em `docs/16`, seção "O papel da Matrícula no ERP": *"matrícula ativa é a condição de elegibilidade para reservar Aula"*.
- **Integração com Financeiro**: `Plano.quantidadeAulas` (já existe, `Int?`, "null = ilimitado") é o ponto de integração óbvio — um plano pode limitar quantas aulas por período o aluno pode frequentar. **Enforcement fica fora de escopo neste módulo** — ver seção 7, item de impacto financeiro.
- **Negócio**: reduz no-show (aluno esquece que tem aula), dá visibilidade de ocupação (quais turmas estão cheias/vazias, quando abrir uma nova turma), e é pré-requisito para qualquer relatório de frequência/retenção — o tipo de dado que só um ERP de verdade tem, mesmo critério de valor já usado em `docs/16`/`docs/17` ([[feedback_academia_facing_value]]).

### Arquitetura base (já aprovada, ponto de partida desta análise)

```
Turma  →  Recorrência  →  Aula
```

- **Turma** — o grupo (ex.: "Funcional 7h", professor titular, modalidade, capacidade).
- **Recorrência** — quando as aulas desse grupo acontecem (pode haver mais de uma por Turma — ver item 3 abaixo).
- **Aula** — a ocorrência concreta numa data específica, gerada de uma Recorrência ou avulsa ("aula extra").

Esta análise reutiliza essa arquitetura integralmente e propõe **uma única evolução** sobre ela (item 6 da seção 2, `TurmaAluno`), com justificativa explícita — nenhuma outra camada é adicionada sem necessidade comprovada.

## 2. Modelagem proposta

### 1. `Modalidade` — entidade própria, não texto livre

Diferente de `Lancamento.categoria` (que ficou texto livre no Módulo 3 por não ter um 2º consumidor real ainda — `docs/17`, item 8), Modalidade tem um 2º/3º consumidor real e imediato: a mesma modalidade ("Funcional", "Musculação", "Spinning") normalmente aparece em **várias Turmas diferentes** (professores/horários diferentes), e cor de exibição na grade semanal só funciona se o dado for estruturado (texto livre "funcional"/"Funcional"/"FUNCIONAL" quebraria agrupamento/filtro). Proposta: `Modalidade` como cadastro simples — `nome`, `cor` (hex, opcional), `status` (reaproveita `UserStatus`, mesmo padrão de `Plano`). Já estava planejada para este momento exato em `docs/02-banco-de-dados.md` ("só entra quando o módulo de Agenda existir de fato") e adiada deliberadamente em `docs/16`, item 7.

### 2. `Turma` — o grupo, reaproveitando `UserStatus`

Campos: `nome`, `modalidadeId` (obrigatória), `professorId` (titular padrão), `capacidadeMaxima` (`Int?`, `null` = ilimitado — mesma convenção de `Plano.quantidadeAulas`), `local` (`String?`, texto livre — uma `Sala` como entidade própria fica de fora até um 2º caso real pedir, mesmo critério de `Lancamento.categoria`), `status` (`UserStatus`, não o ciclo rico de `MatriculaStatus` — Turma não tem "trancamento", só ativa/inativa, mesmo padrão de `Plano`).

Sem constraint de nome único por academia (diferente de `Plano`) — é plausível ter duas Turmas com o mesmo nome em horários/professores diferentes (ex. "Funcional" de manhã e à noite, cada uma sua própria Turma).

**O papel de `Turma` no domínio — explícito antes do MS3, para não virar um "god object" à medida que `Recorrencia`/`Aula`/`TurmaAluno` entram nos MS seguintes:**

- `Turma` representa **apenas o agrupamento lógico** — a identidade do grupo (nome, modalidade, professor titular, capacidade, local). Nada além disso.
- `Turma` **não representa uma aula** — nenhuma ocorrência concreta vive aqui; isso é `Aula`.
- `Turma` **não representa um horário** — nenhum dia da semana, hora ou duração vive aqui; isso é `Recorrencia`.
- `Turma` **não representa uma recorrência** — o padrão de repetição (semanal/mensal/intervalada) é uma entidade própria, não um campo de `Turma`.
- `Turma` **não representa presença** — frequência é um dado por (aluno, aula), não por (aluno, turma); isso é `AulaAluno.presenca`.
- Alunos pertencem a uma `Turma` **através de `TurmaAluno`** — nunca uma FK direta `Turma.alunoIds` ou equivalente.
- **O calendário nasce de `Recorrencia`** — é ela que sabe "quando"; `Turma` não sabe nada sobre tempo.
- **Cada ocorrência concreta é uma `Aula`** — o único lugar onde data, horário efetivo, status (agendada/cancelada) e professor daquele dia específico existem.

Na prática, isso significa que o MS3 (Turmas) entrega **só** CRUD de `Turma` — nome, modalidade, professor titular, capacidade, local, status. Nenhuma tela ou endpoint deste MS lida com horário, recorrência, aula ou matrícula de aluno — essas seções do Detalhe da Turma continuam `EmptyState.comingSoon` até seus MS respectivos (MS4/MS5/MS6).

### 3. `Recorrencia` — uma linha por padrão de repetição, não um array de dias

**Duas invariantes explícitas antes do MS4, para não deixar dúvida de propriedade nem de cardinalidade à medida que Recorrência ganha service/controller/tela própria:**

1. **Recorrência pertence exclusivamente à Turma — nunca diretamente ao Professor.** `Recorrencia.turmaId` é a única FK "dona"; `Recorrencia.professorId` (opcional) é só um *override* pontual do professor titular da Turma para aquele padrão específico, não uma segunda forma de a Recorrência "pertencer" a alguém. Um professor não tem uma lista própria de Recorrências fora do contexto de uma Turma — o que existe é `Professor.recorrenciasComoTitular` (a relação inversa, útil pra "quais recorrências este professor cobre", mas sempre navegada a partir da Turma que a criou).
2. **Uma Turma pode ter múltiplas Recorrências, cada uma um padrão independente de geração.** Não há unicidade nem limite de `Recorrencia` por `turmaId` — o gerador de `Aula` (MS6) processa cada `Recorrencia` isoladamente, e o conjunto de todas as Recorrências ativas de uma Turma é que define, na prática, sua grade de horários completa. Exemplos reais da mesma Turma: "segunda e quarta" + "terça e quinta" (duas linhas `SEMANAL`, `diaSemana` diferente) + "sábado" (uma 3ª linha `SEMANAL`) + "horário especial de férias" (uma 4ª linha, tipo `INTERVALADA` ou `SEMANAL` com `dataInicioVigencia`/`dataFimVigencia` delimitando só o período de férias, coexistindo com as demais).

Uma Turma com aulas segunda/quarta/sexta às 7h tem **3 linhas de `Recorrencia`** (uma por dia da semana), não uma linha com um campo `diasSemana: [1,3,5]`. Motivo: cada dia pode ter vigência/professor diferentes de forma independente (ex.: "a partir de agosto, sexta passa a ser com a Professora Ana") sem precisar reescrever um array inteiro — e o gerador de `Aula` trata cada `Recorrencia` isoladamente, mais simples de testar.

Campos: `tipo` (`SEMANAL | MENSAL | INTERVALADA`), e só o(s) campo(s) relevante(s) ao tipo (validado no service, mesmo padrão condicional de `Mensalidade.motivoCancelamentoDetalhe` obrigatório só quando `motivoCancelamento = OUTRO`):
- `SEMANAL` → `diaSemana` (0-6).
- `MENSAL` → `diaDoMes` (1-31, dia fixo do calendário — não "1ª segunda-feira do mês"; ver seção 7, decisão a confirmar).
- `INTERVALADA` → `intervaloDias` (ex.: 14 = quinzenal), contado a partir de `dataInicioVigencia`.

`horaInicio` (`String`, formato `"HH:mm"`) + `duracaoMinutos` (`Int`) — evita depender de um tipo "hora" do Postgres/Prisma (não portável de forma simples) e evita ambiguidade de fuso horário que um `DateTime` completo introduziria para um dado que é puramente "que horas do dia". `professorId` opcional (override do titular da Turma só para esta recorrência — ex.: sexta é sempre com outro professor). `dataInicioVigencia`/`dataFimVigencia` (`DateTime?`) delimitam quando esse padrão vale — perto do princípio de vigência já usado em `Matricula`. `ativo` (`Boolean`) permite desligar uma recorrência sem apagar histórico.

### 4. `Aula` — sempre snapshot, nunca referência viva

Mesmo princípio de `Matricula.valor`/`Mensalidade.valor` (`docs/16` item 1, `docs/17` item 6): `horaInicio`, `duracaoMinutos`, `professorId` e `capacidadeMaxima` são **copiados** da `Recorrencia`/`Turma` no momento da geração, não lidos ao vivo. Isso é o que permite:
- Um **professor substituto** pontual — editar `Aula.professorId` de uma ocorrência específica sem tocar `Turma`/`Recorrencia` (item 9 abaixo).
- Mudar o horário/professor padrão da Turma **sem alterar retroativamente** aulas já geradas (ver seção 7, decisão a confirmar).
- Uma mudança de `capacidadeMaxima` da Turma não estourar/encolher silenciosamente a capacidade de aulas já geradas com inscritos.

`recorrenciaId` é **opcional** — `null` é exatamente o caso de "aula extra" (sessão avulsa, sem recorrência por trás, criada manualmente numa Turma existente). `turmaId` é **obrigatório** — mesmo uma aula extra pertence a alguma Turma (ex.: workshop pontual vira sua própria Turma sem nenhuma Recorrência, só aulas avulsas).

`status` guarda só `AGENDADA | CANCELADA` — "realizada" **não é armazenado**, é sempre calculado (`status == AGENDADA && data < hoje`), mesmo princípio de `Mensalidade.atrasada` (`docs/17`, item 1): não introduzir um scheduler só para manter um campo derivável em dia (o projeto não tem infraestrutura de cron hoje).

`motivoCancelamento` — texto livre, sem categorização (mesmo critério de `Mensalidade.motivoCancelamento`: sem um 2º caso de uso real pedindo relatório agrupado ainda).

### 5. `AulaAluno` — o vínculo por ocorrência (presença, fila, reposição)

Um `AulaAluno` por (aula, aluno) — `@@unique([aulaId, alunoId])`. `tipo`: `MATRICULADO | FILA_ESPERA | REPOSICAO`. `presenca` (`PresencaStatus?`, `null` = ainda não marcado) — **é aqui que mora "presença"**, não numa entidade separada (ver seção "Entidades avaliadas e não criadas" abaixo). Além de `PRESENTE`/`AUSENTE`, o enum já nasce com `JUSTIFICADA` (falta justificada — atestado, aviso prévio etc.) mesmo sem um fluxo de aprovação por trás nesta fase: é só um 3º valor possível, adicionar depois exigiria migration + backfill numa tabela que já estaria populada, custo desproporcional ao de incluir agora. `reposicaoDeAulaAlunoId` (auto-relacionamento opcional, único) aponta para o `AulaAluno` original (de outra aula, cancelada ou perdida) que esta reposição substitui — **é aqui que mora "reposição"**, também sem entidade separada.

Cancelar uma `Aula` **não apaga** os `AulaAluno` dela — o registro de quem estava inscrito continua existindo (histórico), só o `Aula.status = CANCELADA` explica por que ninguém tem presença marcada naquele dia.

### 6. `TurmaAluno` — a evolução proposta sobre o modelo de 3 camadas

**Esta é a única mudança real sobre a arquitetura Turma → Recorrência → Aula descrita na proposta original, e por isso é o item mais importante desta seção.**

Sem `TurmaAluno`, a única forma de um aluno "estar matriculado numa Turma" seria repetir manualmente a inclusão dele em **cada** `Aula` gerada — o que não corresponde a como uma academia real funciona: o aluno se matricula na Turma **uma vez** ("eu treino Funcional segunda/quarta/sexta às 7h") e passa a aparecer automaticamente em toda aula futura daquela Turma até sair. Os casos de uso que o dono do produto pediu para avaliar — "Matrícula em turma" como item próprio, distinto de "Frequência" — já sugerem essa relação permanente separada da relação por ocorrência.

Proposta: `TurmaAluno` (vínculo permanente aluno↔turma: `turmaId`, `alunoId`, `matriculaId`, `status` `ATIVO|INATIVO`, `dataInicio`, `dataFim?`). Toda vez que uma `Aula` é gerada a partir de uma `Recorrencia`, o gerador cria automaticamente um `AulaAluno(tipo=MATRICULADO)` para cada `TurmaAluno` ativo naquele momento — **snapshot da lista de matriculados**, mesmo princípio dos demais campos da própria `Aula` (item 4): quem sai da Turma depois não desaparece retroativamente das aulas passadas.

`matriculaId` é obrigatório em `TurmaAluno` — decorre diretamente da decisão de elegibilidade (seção 7). `@@unique([turmaId, alunoId])` — só um vínculo ativo por aluno por turma (soft delete quando sai; se voltar depois, é uma nova linha, mesmo espírito de "renovação = nova linha" já usado em `Matricula`, `docs/16` item 3).

**Invariante explícita antes do MS5, para o MS5 não antecipar nada do MS6:**

1. **`TurmaAluno` representa apenas a inscrição permanente do aluno na Turma.** É o registro de "este aluno está matriculado nesta turma", nada além disso — sem data de aula, sem presença, sem nenhum dado por ocorrência.
2. **`TurmaAluno` nunca cria, altera ou remove registros de `AulaAluno`.** As duas tabelas não se tocam em nenhuma direção a partir do MS5 — inscrever, cancelar ou reinscrever um aluno numa Turma (`TurmaAluno`) não gera, edita nem apaga nenhuma linha de `AulaAluno`.
3. **`AulaAluno` nasce exclusivamente durante a geração de Aulas (MS6)**, como snapshot dos `TurmaAluno` ativos naquele momento exato — é o gerador de Aulas, e só ele, que lê `TurmaAluno` pra popular `AulaAluno`; `TurmaAluno` nunca escreve em `AulaAluno` diretamente.

**Consequência prática para o MS5:** a implementação deve ficar **inteiramente independente** da estratégia de geração de Aulas do MS6 — nenhuma sincronização automática entre `TurmaAluno` e `AulaAluno` nesta sprint (nenhum hook, trigger, listener ou chamada cruzada de serviço). O MS5 entrega só CRUD de `TurmaAluno` (inscrever/desinscrever aluno, respeitando elegibilidade e capacidade da seção 7); a leitura de `TurmaAluno` para popular `AulaAluno` é responsabilidade exclusiva do gerador do MS6, implementado só quando o MS6 chegar.

### 7. Enums novos

```prisma
enum RecorrenciaTipo {
  SEMANAL
  MENSAL
  INTERVALADA
}

enum AulaStatus {
  AGENDADA
  CANCELADA
}

enum AulaAlunoTipo {
  MATRICULADO
  FILA_ESPERA
  REPOSICAO
}

enum PresencaStatus {
  PRESENTE
  AUSENTE
  JUSTIFICADA
}
```

`Turma`/`TurmaAluno`/`Modalidade` reaproveitam `UserStatus` — nenhum enum novo para eles.

### 8. `Feriado` — cadastro próprio por academia, datas explícitas

Diferentes academias fecham em dias diferentes (feriados estaduais/municipais, recesso próprio de fim de ano) — um calendário nacional fixo embutido no código não serve. Proposta: `Feriado` tenant-scoped (`nome`, `data`), sem repetição automática anual no MVP (uma data de Natal cadastrada em 2026 não "aparece sozinha" em 2027 — a academia recadastra a cada ano; ver seção 7, decisão a confirmar). Usado em dois pontos: (a) o gerador de `Aula` pula datas com `Feriado` cadastrado; (b) cadastrar um `Feriado` cancela automaticamente qualquer `Aula` já gerada para aquela data (efeito colateral explícito e imediato de uma ação do usuário, não invisível — mesmo espírito do princípio de auditabilidade financeira, `docs/15`, aplicado aqui à agenda).

### Rascunho de schema (Prisma) — para validação, não para aplicar ainda

```prisma
model Modalidade {
  id         String   @id @default(uuid())
  academiaId String
  academia   Academia @relation(fields: [academiaId], references: [id], onDelete: Cascade)

  nome   String
  cor    String? // hex, ex. "#3B82F6" — cor de exibição na grade
  status UserStatus @default(ATIVO)

  deletedAt DateTime?
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt

  turmas Turma[]

  @@unique([academiaId, nome])
  @@index([academiaId])
  @@map("modalidades")
}

model Turma {
  id         String   @id @default(uuid())
  academiaId String
  academia   Academia @relation(fields: [academiaId], references: [id], onDelete: Cascade)

  nome             String
  modalidadeId     String
  modalidade       Modalidade @relation(fields: [modalidadeId], references: [id])
  professorId      String     // titular padrão — sobrescrevível por Recorrencia/Aula
  professor        Professor  @relation(fields: [professorId], references: [id])
  capacidadeMaxima Int?       // null = ilimitado
  local            String?
  status           UserStatus @default(ATIVO)

  deletedAt DateTime?
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt

  recorrencias Recorrencia[]
  aulas        Aula[]
  turmaAlunos  TurmaAluno[]

  @@index([academiaId])
  @@index([modalidadeId])
  @@index([professorId])
  @@map("turmas")
}

model Recorrencia {
  id         String   @id @default(uuid())
  academiaId String
  academia   Academia @relation(fields: [academiaId], references: [id], onDelete: Cascade)

  turmaId String
  turma   Turma  @relation(fields: [turmaId], references: [id])

  tipo RecorrenciaTipo

  diaSemana     Int? // 0-6 — obrigatório se tipo = SEMANAL
  diaDoMes      Int? // 1-31 — obrigatório se tipo = MENSAL
  intervaloDias Int? // obrigatório se tipo = INTERVALADA

  horaInicio     String // "HH:mm"
  duracaoMinutos Int

  professorId String?    // override do titular só para esta recorrência
  professor   Professor? @relation(fields: [professorId], references: [id])

  dataInicioVigencia DateTime
  dataFimVigencia    DateTime?
  ativo              Boolean   @default(true)

  deletedAt DateTime?
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt

  aulas Aula[]

  @@index([academiaId])
  @@index([turmaId])
  @@map("recorrencias")
}

model Aula {
  id         String   @id @default(uuid())
  academiaId String
  academia   Academia @relation(fields: [academiaId], references: [id], onDelete: Cascade)

  turmaId       String
  turma         Turma        @relation(fields: [turmaId], references: [id])
  recorrenciaId String?      // null = aula extra (avulsa)
  recorrencia   Recorrencia? @relation(fields: [recorrenciaId], references: [id])

  data             DateTime
  horaInicio       String // snapshot da Recorrencia (ou valor manual, aula extra)
  duracaoMinutos   Int
  professorId      String    // snapshot — permite substituto pontual
  professor        Professor @relation(fields: [professorId], references: [id])
  capacidadeMaxima Int?      // snapshot de Turma.capacidadeMaxima na geração

  status             AulaStatus @default(AGENDADA)
  motivoCancelamento String?

  createdByUserId String
  createdByUser   User   @relation(fields: [createdByUserId], references: [id])

  deletedAt DateTime?
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt

  alunos AulaAluno[]

  @@unique([recorrenciaId, data]) // idempotência da geração
  @@index([academiaId])
  @@index([turmaId])
  @@index([data])
  @@map("aulas")
}

model TurmaAluno {
  id         String   @id @default(uuid())
  academiaId String
  academia   Academia @relation(fields: [academiaId], references: [id], onDelete: Cascade)

  turmaId     String
  turma       Turma     @relation(fields: [turmaId], references: [id])
  alunoId     String
  aluno       Aluno     @relation(fields: [alunoId], references: [id])
  matriculaId String
  matricula   Matricula @relation(fields: [matriculaId], references: [id])

  status     UserStatus @default(ATIVO)
  dataInicio DateTime   @default(now())
  dataFim    DateTime?

  deletedAt DateTime?
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt

  aulaAlunos AulaAluno[]

  @@unique([turmaId, alunoId])
  @@index([academiaId])
  @@index([alunoId])
  @@map("turma_alunos")
}

model AulaAluno {
  id         String   @id @default(uuid())
  academiaId String
  academia   Academia @relation(fields: [academiaId], references: [id], onDelete: Cascade)

  aulaId       String
  aula         Aula        @relation(fields: [aulaId], references: [id])
  alunoId      String
  aluno        Aluno       @relation(fields: [alunoId], references: [id])
  turmaAlunoId String?     // preenchido quando a origem é a matrícula permanente na turma
  turmaAluno   TurmaAluno? @relation(fields: [turmaAlunoId], references: [id])

  tipo     AulaAlunoTipo   @default(MATRICULADO)
  presenca PresencaStatus? // null = não marcado ainda; PRESENTE | AUSENTE | JUSTIFICADA

  reposicaoDeAulaAlunoId String?    @unique
  reposicaoDeAulaAluno   AulaAluno? @relation("Reposicao", fields: [reposicaoDeAulaAlunoId], references: [id])
  reposicaoGerada        AulaAluno? @relation("Reposicao")

  deletedAt DateTime?
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt

  @@unique([aulaId, alunoId])
  @@index([academiaId])
  @@index([aulaId])
  @@index([alunoId])
  @@map("aula_alunos")
}

model Feriado {
  id         String   @id @default(uuid())
  academiaId String
  academia   Academia @relation(fields: [academiaId], references: [id], onDelete: Cascade)

  nome String
  data DateTime

  deletedAt DateTime?
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt

  @@unique([academiaId, data])
  @@index([academiaId])
  @@map("feriados")
}
```

`Academia` ganha as relações opostas de todas as 6 tabelas acima. `Professor`/`Aluno`/`Matricula`/`User` ganham as relações opostas específicas (`turmasTitular`, `matriculas`/`turmaAlunos`, `createdByUser` etc.), mesmo padrão já usado em todo o schema.

Novas ações de `AuditAction`: `MODALIDADE_CREATED/UPDATED/DELETED`, `TURMA_CREATED/UPDATED/STATUS_CHANGED/DELETED`, `RECORRENCIA_CREATED/UPDATED/DELETED`, `AULA_GERADA/CANCELADA/SUBSTITUICAO/EXTRA_CRIADA/DELETED`, `TURMA_ALUNO_MATRICULADO/REMOVIDO`, `AULA_ALUNO_PRESENCA_MARCADA/REPOSICAO_CRIADA`, `FERIADO_CREATED/DELETED` — mesmo padrão de Matrícula/Financeiro.

## Entidades avaliadas e não criadas

- **Presença** — vive em `AulaAluno.presenca` (`PresencaStatus?`: `PRESENTE | AUSENTE | JUSTIFICADA`, `null` = não marcado). Não há necessidade de uma entidade própria: presença é sempre "este aluno, nesta aula específica", exatamente o grão de `AulaAluno` — criar uma tabela separada só duplicaria a chave (aulaId, alunoId) sem nenhum dado adicional que já não caiba num campo.
- **Reposição** — vive em `AulaAluno.tipo = REPOSICAO` + `reposicaoDeAulaAlunoId` (auto-relacionamento). Mesmo raciocínio: reposição não é um conceito com vida própria fora de "um vínculo aluno↔aula que aponta pra outro vínculo aluno↔aula". Nenhum fluxo de aprovação (`SolicitacaoAgenda`, já cogitada em `docs/02` para o portal do aluno) faz parte deste módulo — quem cria a reposição é a recepção diretamente, não um pedido do aluno esperando aprovação (isso só faz sentido quando existir o Portal do Aluno, Módulo 10).
- **Calendário** — não é uma entidade, é uma **visão de leitura** sobre `Aula` (`GET` filtrado por intervalo de data + filtros opcionais de `turmaId`/`professorId`/`modalidadeId`/`status`). Diário/semanal/mensal são apenas granularidades diferentes do mesmo filtro — nenhuma tabela nova, resolvido inteiramente na camada de consulta/tela. **O DTO de consulta já nasce (MS7) com os 4 filtros aceitos, mesmo que a UI inicial só exponha parte deles** — evita alterar o contrato do endpoint depois que uma tela específica (ex.: agenda por professor) pedir o filtro que faltava.
- **AgendaPessoalProfessor** — avaliado e descartado para este módulo. O único caso de uso concreto pedido ("professor substituto") já é resolvido pontualmente por `Aula.professorId` (item 4). Uma agenda pessoal de disponibilidade/bloqueios (férias, horários que o professor não pode dar aula) é uma entidade genuinamente nova sem um 2º caso de uso real ainda apontado — mesmo critério de "não construir até existir necessidade comprovada" já aplicado a `AppAutocompleteField`/scheduler/`CategoriaLancamento`. Fica registrado aqui como candidato futuro se a academia realmente precisar bloquear horários de professor de forma estruturada.

## 3. Regras de negócio

1. **Elegibilidade** — só um aluno com `Matricula.status = ATIVA` pode ser incluído em `TurmaAluno` (matrícula permanente numa turma) ou em `AulaAluno` avulso. Uma `Matricula` `TRANCADA` não permite novo vínculo, mas não remove vínculos já existentes automaticamente (ver risco na seção 6). **Decisão a confirmar — seção 7.**
2. **Capacidade** — `TurmaAluno` novo é bloqueado se a contagem de `TurmaAluno` ativos já atingiu `Turma.capacidadeMaxima` (quando não `null`); o aluno excedente entra como `FILA_ESPERA` (linha de `AulaAluno`, não de `TurmaAluno` — fila de espera é por ocorrência específica ou pela próxima vaga da turma como um todo, ver fluxo na seção 5). Promoção de fila de espera é **manual** (recepção decide), nunca automática — sem `NotificationProvider` real ainda, uma promoção automática seria silenciosa. **Decisão a confirmar — seção 7.**
3. **Geração de `Aula`** — manual, sob demanda (botão "Gerar aulas do período"), mesmo padrão de `Mensalidade` (`docs/17`, item 2: sem scheduler nesta fase). **Determinística e totalmente idempotente**: rodar duas (ou mais) vezes sobre o mesmo período produz exatamente o mesmo estado final — não só `Aula` (por `(recorrenciaId, data)`), mas também `AulaAluno` (a população automática a partir de `TurmaAluno` não pode duplicar linhas nem sobrescrever presença/reposição já registradas numa aula que já existia). Uma aula já gerada — e possivelmente já alterada (cancelada, com substituto, com presença marcada) — nunca é recriada nem revertida por uma nova rodada de geração sobre o mesmo período; o gerador só adiciona o que ainda não existe. Pula datas com `Feriado` cadastrado. **Janela padrão a confirmar — seção 7.**
4. **Cancelamento de `Aula`** — muda `status` para `CANCELADA` com `motivoCancelamento` opcional; não apaga `AulaAluno` (histórico preservado). Não gera reposição automaticamente para todos os matriculados — a recepção cria a reposição manualmente, aluno a aluno, quando fizer sentido (nem todo cancelamento gera reposição — ex.: se a academia decide simplesmente não repor).
5. **Aula extra** — criada manualmente numa `Turma` existente, sem `recorrenciaId`. Mesmas regras de capacidade/matrícula de qualquer outra aula.
6. **Professor substituto** — edição pontual de `Aula.professorId`, sem afetar `Turma.professorId` nem `Recorrencia.professorId`. Mudar o professor titular da `Turma` (ou de uma `Recorrencia`) **não retroage** sobre `Aula`s já geradas — só afeta gerações futuras. **Decisão a confirmar — seção 7.**
7. **Frequência** — `AulaAluno.presenca` (`PRESENTE | AUSENTE | JUSTIFICADA`) só é marcável para aulas com `data <= hoje` (não faz sentido marcar presença de uma aula futura) e `status = AGENDADA` (uma aula cancelada não tem presença a marcar). `JUSTIFICADA` nasce no enum desde o MS1 para evitar uma migration futura, mas o fluxo de anexar/validar justificativa (atestado etc.) fica fora de escopo neste módulo — nesta fase é só um 3º valor que a recepção pode marcar manualmente, sem workflow de aprovação por trás.
8. **Feriado** — cadastrar um `Feriado` cancela automaticamente (`status = CANCELADA`, `motivoCancelamento` preenchido com o nome do feriado) qualquer `Aula` já gerada para aquela data, e faz o gerador pular a data em gerações futuras. **Decisão a confirmar — seção 7.**
9. **Impacto financeiro** — `Plano.quantidadeAulas` **não é aplicado** neste módulo (sem enforcement de limite de aulas por período). Fica registrado como integração futura possível, não implementada agora. **Decisão a confirmar — seção 7.**
10. **Acesso por papel** — endpoints de Agenda restritos a `ACADEMIA_ADMIN`/`RECEPCIONISTA`, mesmo critério de Financeiro (`Professor` ainda não tem login/conta própria — ver `docs/14-alunos-professores.md`). **Decisão a confirmar — seção 7.**
11. **Soft delete vs. cancelamento** — mesma distinção já estabelecida para Matrícula/Mensalidade (`docs/16` item 8, `docs/17`): `deletedAt` em `Aula`/`Turma`/`TurmaAluno` é reservado a erro de cadastro; o encerramento de negócio de verdade é `status = CANCELADA` (Aula) ou inativar/sair (Turma/TurmaAluno).

## 4. Casos de uso

1. Academia cadastra uma `Modalidade` (ex. "Funcional", cor verde).
2. Academia cria uma `Turma` (Funcional, professor titular, capacidade 15, modalidade Funcional).
3. Academia cadastra 3 `Recorrencia`s pra essa Turma (segunda/quarta/sexta, 7h, 60min).
4. Sistema gera as `Aula`s do período (botão "Gerar aulas") — pula datas com `Feriado`.
5. Recepção matricula um `Aluno` na Turma (`TurmaAluno`) — aluno passa a aparecer automaticamente como `MATRICULADO` em toda `Aula` futura já gerada e nas próximas gerações.
6. Turma atinge a capacidade máxima — próximo aluno entra em fila de espera.
7. Uma vaga abre (aluno sai da turma) — recepção promove manualmente o primeiro da fila.
8. Recepção marca presença/falta dos alunos de uma aula já realizada.
9. Professor titular fica doente — recepção define um substituto pontual só naquela `Aula`.
10. Uma aula é cancelada (imprevisto) — recepção agenda reposição pontual pra um ou mais alunos numa aula futura com vaga.
11. Professor decide dar uma aula extra num sábado — recepção cria uma `Aula` avulsa (sem recorrência) na Turma existente.
12. Feriado nacional é cadastrado — aulas já geradas naquele dia são canceladas automaticamente.
13. Dono da academia consulta a agenda semanal/mensal, filtrando por professor ou modalidade.
14. Dono da academia consulta a frequência de um aluno específico (seção "Frequência" já reservada em `AlunoDetailScreen`).
15. Detalhe do professor mostra as turmas vinculadas a ele (seção "Turmas" já reservada em `ProfessorDetailScreen`).
16. Aluno tranca a matrícula — permanece vinculado à Turma (`TurmaAluno` ativo) mas não deveria ser contado como frequentador ativo enquanto trancado (ver risco, seção 6).

## 5. Fluxos operacionais

### Geração de Aulas

1. Recepção define um intervalo (`dataInicio`, `dataFim`) — ex.: próximos 30 dias.
2. Para cada `Recorrencia` ativa cuja vigência intersecta o intervalo: calcula todas as datas correspondentes (semanal: cada ocorrência do `diaSemana`; mensal: o `diaDoMes` em cada mês do intervalo; intervalada: `dataInicioVigencia + k × intervaloDias` para todo `k` que cai no intervalo).
3. Remove datas com `Feriado` cadastrado.
4. Para cada data restante, verifica se já existe `Aula` para `(recorrenciaId, data)` — se sim, pula por completo (não toca a aula existente nem seus `AulaAluno`, mesmo que a lista de `TurmaAluno` tenha mudado desde então); se não, cria, copiando `horaInicio`/`duracaoMinutos`/`professorId` (da Recorrência ou, se nula, da Turma)/`capacidadeMaxima` (da Turma).
5. Só para a `Aula` recém-criada (nunca para uma já existente — reforça a idempotência do passo 4), cria um `AulaAluno(tipo=MATRICULADO)` para cada `TurmaAluno` ativo da Turma naquele momento. Rodar a geração de novo sobre o mesmo período, sem nenhuma `Recorrencia`/`TurmaAluno` nova, não cria nem altera nenhuma linha — determinístico por construção.

**Duas invariantes explícitas antes do MS6, para não deixar dúvida de comportamento à medida que o gerador ganha código de verdade:**

1. **O gerador de Aulas nunca altera registros já existentes — ele apenas cria Aulas inexistentes.** Depois que uma `Aula` é criada, ela passa a representar um **fato histórico**: mudanças futuras em `Turma`, `Recorrencia`, `Professor` ou `TurmaAluno` nunca modificam retrospectivamente essa `Aula` — nem seus campos-snapshot (`horaInicio`/`duracaoMinutos`/`professorId`/`capacidadeMaxima`), nem seus `AulaAluno`. O gerador só lê essas quatro entidades para decidir o que criar; nunca escreve nelas, e nunca volta a escrever numa `Aula`/`AulaAluno` que já existia antes desta rodada.
2. **A geração é completamente determinística e idempotente.** Executar a mesma geração (mesma Turma, mesmo `dataInicio`/`dataFim`) quantas vezes for, sobre o mesmo estado de `Recorrencia`/`TurmaAluno`/`Feriado`, produz exatamente o mesmo estado final do banco: sem duplicar `Aula` (a existência por `(recorrenciaId, data)` é sempre conferida antes de criar, e a constraint `@@unique([recorrenciaId, data])` é a garantia de última instância), sem alterar snapshot algum de uma `Aula` já existente, sem recriar ou duplicar `AulaAluno` de uma `Aula` já existente, sem trocar `professorId` de uma aula já gerada, sem alterar `horaInicio`/`duracaoMinutos` já gravados. Rodar a geração de novo é sempre uma operação **aditiva no máximo** (só acrescenta o que ainda não existe) ou **sem efeito nenhum** (se não há nada novo a criar) — nunca uma correção retroativa.

### Calendário (MS7) — uma visão operacional sobre `Aula`, nunca uma entidade própria

**Quatro invariantes explícitas antes do MS7:**

1. **`Aula` continua sendo o único fato do calendário.** O Calendário apenas organiza e apresenta `Aula`s já existentes — não existe uma tabela `Calendario`/`Evento` nem qualquer dado novo criado exclusivamente para a visão de calendário. Nenhuma informação operacional (data, horário, professor, status, turma, alunos) pode existir só na visão do calendário; tudo vem de `Aula`/`Turma`/`Professor`/`AulaAluno` já modelados.
2. **`Aula` cancelada nunca é removida — ela apenas muda de `status` para `CANCELADA`.** `deletedAt` continua reservado a erro de cadastro (item 11); cancelar é sempre uma mudança de status, nunca um soft delete. O histórico permanece íntegro: uma `Aula` cancelada continua aparecendo no calendário e em qualquer listagem, só com o status refletindo o cancelamento.
3. **Professor substituto é uma exceção pontual da `Aula`, nunca uma mudança de Turma/Recorrência/professor titular.** Editar `Aula.professorId` para um substituto não toca `Turma.professorId` nem `Recorrencia.professorId` em nenhuma hipótese — o titular da Turma continua sendo o titular depois que a substituição pontual é aplicada e depois que ela deixa de ser a "aula atual" (não há reversão automática; é assim que já estava desde o MS4, reafirmado aqui).
4. **Aula extra é sempre uma `Aula` independente (`recorrenciaId = null`)** — nunca cria, altera ou depende de uma `Recorrencia`. Uma vez criada, é uma `Aula` como qualquer outra: some snapshot, fato histórico, sujeita às mesmas regras de cancelamento/substituição, nunca "regenerada" ou tocada retroativamente por nenhuma rodada futura do gerador do MS6 (que só enxerga `Aula`s com `recorrenciaId` preenchido).

**Consequência prática de escopo (leitura direta das quatro invariantes acima, não uma nova decisão de negócio):** as três operações do MS7 (cancelar, definir professor substituto, criar aula extra) e a listagem por filtros escrevem/leem **só** `Aula` — nenhuma delas toca `Recorrencia`, `TurmaAluno` ou `AulaAluno` em nenhuma circunstância. Em particular, criar uma aula extra **não** popula `AulaAluno` automaticamente a partir de `TurmaAluno` (diferente do gerador do MS6, que só faz isso para a `Aula` que ele mesmo acabou de criar) — populacional de `AulaAluno` fica fora do escopo do MS7; se um caso real pedir isso depois, é uma extensão pontual da criação de aula extra, não uma revisão desta sprint.

### Frequência (MS8) — a presença pertence exclusivamente a `AulaAluno`

**Quatro invariantes explícitas antes do MS8:**

1. **A presença pertence exclusivamente à entidade `AulaAluno`.** Ela nunca pertence diretamente a `Aula`, `Turma` ou `Matricula` — não existe (nem vai existir) um campo de presença em nenhuma dessas três; `AulaAluno.presenca` é o único lugar onde esse dado mora, mesmo como já registrado na modelagem original (seção 2, item 5).
2. **Registrar presença nunca altera `Aula`, `Turma`, `Recorrencia` ou `TurmaAluno`.** A única entidade escrita por qualquer operação de frequência é `AulaAluno` — nem o `status` da `Aula`, nem `TurmaAluno.status`, nem nenhum outro campo fora de `AulaAluno.presenca` (e o `updatedAt` que vem junto).
3. **Uma `Aula` cancelada nunca recebe presença; uma `Aula` futura também não.** Só `Aula`s **realizadas** podem registrar frequência — "realizada" é o mesmo cálculo já usado em toda a Agenda (`status == AGENDADA && data < hoje`, nunca armazenado, seção 2 item 4): `status == CANCELADA` bloqueia sempre (não importa a data), e `data >= hoje` bloqueia mesmo com `status == AGENDADA` (não faz sentido marcar presença de algo que ainda não aconteceu).
4. **A Frequência é um fato histórico.** Uma vez registrada, uma alteração futura em `Matricula`, `Turma` ou `Professor` nunca modifica presenças já registradas — mesmo princípio de snapshot/imutabilidade retroativa já aplicado a `Aula` (MS6) e ao Calendário (MS7), agora para o último dado operacional do módulo.

**Consequência prática de escopo:** registrar presença é sempre uma operação pontual sobre um `AulaAluno` já existente (nunca cria um novo `AulaAluno`) — um aluno só pode ter presença marcada se já estava vinculado à `Aula` (via `TurmaAluno` no momento da geração, ou avulso). Alterar uma presença já marcada (ex.: corrigir de `AUSENTE` para `JUSTIFICADA` depois que o aluno traz um atestado) é a mesma operação de "registrar", só que sobre um `AulaAluno` que já tinha `presenca` preenchida — sem histórico de mudanças de presença (não pedido, e sem tabela própria pra isso). Reposição e promoção de fila de espera **não** entram neste MS — o pedido desta sprint é só presença/falta/falta justificada; ficam como extensão futura sobre o mesmo `AulaAluno.tipo`/`reposicaoDeAulaAlunoId` já modelados desde o MS1.

### Cancelamento de aula + reposição

1. Recepção cancela uma `Aula` específica (`status = CANCELADA`, motivo opcional).
2. `AulaAluno`s da aula permanecem intactos (histórico).
3. Recepção decide, individualmente, se cada aluno afetado ganha reposição.
4. Para quem ganha: recepção escolhe uma `Aula` futura com vaga e cria um novo `AulaAluno(tipo=REPOSICAO, reposicaoDeAulaAlunoId=<original>)`.
5. A reposição conta pra capacidade da aula de destino como qualquer outro `AulaAluno`.

### Matrícula em turma com fila de espera

1. Recepção tenta adicionar um `TurmaAluno` a uma Turma cheia.
2. Sistema bloqueia a matrícula permanente (`TurmaAluno`) e oferece a opção de colocar o aluno na fila de espera da turma.
3. Fila de espera é modelada como... **decisão de design a resolver na implementação, não nesta análise**: uma opção é `TurmaAluno` com um `status` adicional (`FILA_ESPERA`, exigindo evoluir de `UserStatus` pra um enum próprio); outra é não permitir fila de espera no nível de Turma (só no nível de Aula, via `AulaAluno.tipo=FILA_ESPERA` de ocorrência em ocorrência). Ambas as opções cabem no modelo já proposto sem mudança estrutural — a escolha exata fica para o desenho do MS de Turmas, não bloqueia a aprovação desta análise.
4. Vaga abre — recepção promove manualmente.

### Substituição de professor

1. Recepção abre uma `Aula` específica (ou um conjunto de aulas, se a ausência for por vários dias).
2. Edita `Aula.professorId` para o substituto — `Turma`/`Recorrencia` não são tocadas.
3. Auditoria registra `AULA_SUBSTITUICAO` com o professor titular e o substituto em `metadata`.

## 6. Riscos arquiteturais

- **Concorrência de capacidade** — duas recepcionistas matriculando o último lugar simultaneamente. Mitigação: mesma técnica já usada em `MensalidadesService.marcarPaga` — recontagem dentro de uma transação (`$transaction`) antes de confirmar, não apenas checar e depois inserir.
- **Volume de geração** — gerar `Aula`s para uma janela grande (ex. 1 ano) de uma vez, multiplicado por muitas Turmas, pode criar milhares de linhas numa chamada só. Mitigação: janela padrão pequena (ver seção 7), e considerar processar por Turma/Recorrência em vez de uma única transação gigante.
- **Índices para performance com muitos alunos** — consultas de calendário (`Aula` por intervalo de data, com/sem filtro de turma/professor) precisam de `@@index([academiaId, data])` e `@@index([academiaId, turmaId, data])`; contagem de capacidade precisa de índice em `AulaAluno.aulaId`. Já refletido no rascunho de schema acima.
- **`Matricula` trancada não remove `TurmaAluno` automaticamente** — um aluno que tranca a matrícula continua com `TurmaAluno` ativo (item 16 dos casos de uso) a menos que o sistema faça uma verificação cruzada. Duas opções: (a) o gerador de `Aula` verifica a `Matricula` do `TurmaAluno` no momento de criar cada `AulaAluno` e pula se não estiver `ATIVA` (mais correto, mais uma verificação por geração); (b) confiar que a recepção lembra de tirar o aluno da turma manualmente ao trancar (mais simples, mais frágil). Recomendação: (a) — é uma verificação barata (mesma query já teria que buscar a matrícula pra validar elegibilidade de qualquer forma) e evita o cenário de "aluno trancado aparecendo matriculado numa aula futura". **Não listado como decisão de negócio porque a resposta técnica correta é clara — mencionado aqui por transparência.**
- **Complexidade de `Recorrencia` tipo `MENSAL`** — "dia fixo do mês" tem o mesmo problema de overflow já aceito em `dataVencimentoNoMes` (Financeiro): dia 31 num mês de 30 dias estoura pro mês seguinte. Mesma aproximação, sem calendário comercial dedicado.
- **Fuso horário / DST** — `horaInicio` como string ("HH:mm") evita esse problema por completo (não há conversão de fuso a fazer); `data` continua sendo `DateTime` em UTC como todo o resto do schema.

## Fora do escopo do Módulo 4 (deliberado, não esquecido)

- `SolicitacaoAgenda` (fluxo de aprovação de troca/reposição pelo próprio aluno) — só faz sentido com o Portal do Aluno (Módulo 10).
- `AgendaPessoalProfessor` (disponibilidade/bloqueios do professor) — sem 2º caso de uso real ainda (ver "Entidades avaliadas e não criadas").
- Enforcement de `Plano.quantidadeAulas` (limite de aulas por período) — integração futura possível, não implementada agora.
- Notificação real de aluno (lembrete de aula, aviso de cancelamento) — depende de `NotificationProvider` (Módulo 6/10), interface ainda não implementada.
- Repetição automática anual de `Feriado` — cadastro é por data explícita, recadastrado a cada ano.
- Calendário nacional de feriados pré-carregado — cada academia cadastra os seus.
- Qualquer integração com `AcademiaConfiguracao.horarioFuncionamento` (validar Turma/Aula contra o horário de funcionamento da academia) — mencionada como oportunidade natural na seção 1, não implementada neste módulo.

## Ponta solta encontrada durante a análise (cosmética, não bloqueia)

Várias telas já têm seções `EmptyState.comingSoon` reservadas para Agenda com a tag antiga `'SPRINT 9 · AGENDA'` (de antes da convenção `'MÓDULO N'`, adotada no Módulo 2 MS5): `AlunoDetailScreen` (seções "Frequência"), `ProfessorDetailScreen` (seção "Turmas"), `DashboardScreen` (card "Agenda do dia"). **Corrigido no MS3**: cada uma agora aponta pro MS específico que a implementa (`'MÓDULO 4 · MS8'` Frequência, `'MÓDULO 4 · MS6'` aulas do professor, `'MÓDULO 4 · MS7'` Agenda do dia/calendário) em vez do rótulo genérico `AGENDA`.

## 7. Decisões que precisam da sua aprovação antes do MS1

1. **`TurmaAluno` (nova entidade, evolução do modelo original de 3 camadas)** — vínculo permanente aluno↔turma, separado de `AulaAluno` (vínculo por ocorrência). Sem ele, matricular um aluno numa turma recorrente exigiria adicioná-lo manualmente em cada aula. *Recomendação: aprovar.*
2. **Elegibilidade** — só `Matricula.status = ATIVA` permite entrar numa Turma (`TurmaAluno`) ou numa aula avulsa (`AulaAluno`); sem suporte a aula experimental/avulsa sem matrícula nesta fase. *Recomendação: aprovar; aula experimental fica pra quando houver um caso real pedindo.*
3. **Recorrência mensal** — dia fixo do calendário (ex. "dia 15") em vez de "n-ésimo dia da semana do mês" (ex. "toda 1ª segunda-feira"). *Recomendação: dia fixo no MVP — mais simples, cobre o caso de uso mais comum (avaliação física mensal, workshop mensal).*
4. **Geração de Aula** — manual (botão), sem scheduler, mesmo padrão de Mensalidade. *Falta definir: janela padrão (sugiro 30 dias, com opção de escolher outro intervalo).*
5. **Feriado cancela aulas automaticamente** — cadastrar um Feriado cancela (não apaga) qualquer Aula já gerada pra aquela data. *Recomendação: aprovar — efeito explícito e imediato de uma ação do usuário.*
6. **Fila de espera** — promoção de fila de espera é sempre manual (recepção decide), nunca automática. *Recomendação: aprovar — evita silêncio sem sistema de notificação real.*
7. **Professor substituto** — só override pontual em `Aula.professorId`; sem `AgendaPessoalProfessor` (disponibilidade/bloqueios) neste módulo. *Recomendação: aprovar.*
8. **Mudança de professor/horário titular da Turma não retroage** — só afeta aulas geradas depois da mudança; aulas já geradas mantêm o snapshot antigo (correção pontual via substituição, se necessário). *Recomendação: aprovar.*
9. **Enforcement de `Plano.quantidadeAulas`** — fora de escopo neste módulo (campo já existe, mas o limite não é verificado ao matricular em turma). *Recomendação: aprovar como fora de escopo; revisar quando houver demanda real.*
10. **Acesso por papel** — endpoints de Agenda restritos a `ACADEMIA_ADMIN`/`RECEPCIONISTA`, mesmo critério de Financeiro. *Recomendação: aprovar.*

## Decisões de negócio confirmadas pelo dono do produto (2026-07-13)

Todas as 10 decisões da seção 7 foram confirmadas seguindo a opção recomendada, sem ajustes:

1. **`TurmaAluno`** — aprovado como 4ª entidade (vínculo permanente aluno↔turma).
2. **Elegibilidade** — exigir `Matricula.status = ATIVA` sempre, sem aula avulsa/experimental nesta fase.
3. **Recorrência mensal** — dia fixo do calendário, não n-ésimo dia da semana.
4. **Geração de Aula** — manual, janela padrão de 30 dias.
5. **Feriado cancela automaticamente** — aulas já geradas na data são canceladas ao cadastrar o Feriado.
6. **Fila de espera** — promoção sempre manual, nunca automática.
7. **Professor titular/substituto** — substituição é só um campo pontual em `Aula.professorId`; trocar o titular da Turma não retroage sobre aulas já geradas.
8. **Enforcement de `Plano.quantidadeAulas`** — fora de escopo neste módulo.
9. **Acesso por papel** — endpoints restritos a `ACADEMIA_ADMIN`/`RECEPCIONISTA`.

O modelo de domínio proposto neste documento está validado e pronto para ir a plano de implementação (MS1 do Módulo 4 — schema + migration + services + endpoints + auditoria + testes), aguardando aprovação do plano de micro-sprints antes de iniciar.

## Plano de micro-sprints (proposto)

Mesma cadência do Módulo 3 — cada MS termina compilando, com testes e documentação atualizada. 8 micro-sprints em vez das 7 do pedido original: **`Matrícula em Turma` foi desmembrada de `Geração de Aulas`** para não concentrar as duas peças de maior risco de negócio (elegibilidade/capacidade/fila de espera + o algoritmo de geração em si) numa única sprint — ver justificativa detalhada na proposta apresentada em conversa.

- **MS1 — Backend Base**: schema completo (7 tabelas, 4 enums novos — inclui `PresencaStatus` com `JUSTIFICADA` desde já) numa única migration; serviço/controller só para `Modalidade` e `Feriado` (as duas peças de cadastro simples, pré-requisito das demais).
- **MS2 — Camada de Dados**: `Modalidade`/`Feriado` em `shared_core` (models, APIs, providers) — sem tela ainda.
- **MS3 — Turmas**: CRUD de `Turma` (backend + telas), tela simples de `Modalidade`. Seções de Detalhe pra Recorrências/Alunos/Aulas ainda `EmptyState.comingSoon`.
- **MS4 — Recorrências**: CRUD de `Recorrencia`, gerenciado a partir do Detalhe da Turma (sem tela própria, mesmo padrão de diálogo já estabelecido).
- **MS5 — Matrícula em Turma**: `TurmaAluno` (backend + seção "Alunos matriculados" no Detalhe da Turma) — capacidade, elegibilidade, fila de espera.
- **MS6 — Geração de Aulas**: o algoritmo de geração em si (3 tipos de recorrência, feriado, idempotência determinística — incluindo `AulaAluno`, população automática a partir de `TurmaAluno`).
- **MS7 — Calendário**: consulta de `Aula` por período + os 4 filtros (`turmaId`/`professorId`/`modalidadeId`/`status`, já aceitos no DTO desde este MS mesmo que a UI exponha só parte deles), cancelamento, professor substituto, aula extra, tela de Feriados, view diária/semanal/mensal.
- **MS8 — Frequência**: marcar presença (`PRESENTE`/`AUSENTE`/`JUSTIFICADA`), reposição, promoção de fila de espera, seção "Frequência" do Detalhe do Aluno.
- **Sprint de Consolidação**: revisão de duplicação, qualidade de `CrudApi<T>`, integração frontend/backend, Design System, documentação, débitos técnicos, **e uma revisão específica de performance da geração de aulas** (tempo de execução, nº de consultas ao banco, uso de memória — janelas maiores e academias com muitas turmas/recorrências) — sem funcionalidade nova.

## Histórico

- **2026-07-13**: primeira versão — análise de domínio antes de qualquer implementação do Módulo 4, ao final do Módulo 3 (Financeiro).
- **2026-07-13**: as 10 decisões de negócio (seção 7) confirmadas pelo dono do produto, todas seguindo a opção recomendada. Modelo de domínio considerado fechado para o MVP do Módulo 4.
- **2026-07-13**: plano de micro-sprints proposto (seção acima) — 8 MS em vez das 7 pedidas originalmente, com `Matrícula em Turma` (MS5) desmembrada de `Geração de Aulas` (MS6) para não concentrar as duas regras de negócio mais arriscadas do módulo numa única sprint. Aguardando aprovação para iniciar o MS1.
- **2026-07-13**: plano de 8 MS aprovado sem alterações. Quatro ajustes de documentação pedidos antes do MS1, todos aplicados: (1) geração de `Aula` registrada como determinística e totalmente idempotente, incluindo `AulaAluno` (regra 3, fluxo "Geração de Aulas"); (2) o endpoint de calendário (MS7) já nasce aceitando os 4 filtros (`turmaId`/`professorId`/`modalidadeId`/`status`), mesmo que a UI inicial exponha só parte deles; (3) novo enum `PresencaStatus` (`PRESENTE | AUSENTE | JUSTIFICADA`) substitui o `Boolean?` original de `AulaAluno.presente` — agora `AulaAluno.presenca` — pra não exigir uma migration futura só pra acrescentar um 3º estado; (4) Sprint de Consolidação passa a incluir revisão específica de performance da geração de aulas (tempo, consultas, memória). Aprovado para iniciar o MS1.
- **2026-07-13, MS1**: schema completo (7 tabelas, 4 enums novos, incluindo `PresencaStatus`) numa única migration + `AuditAction` novas (mais `MODALIDADE_STATUS_CHANGED`/`FERIADO_UPDATED`, descobertos como necessários durante a implementação — mesmo padrão condicional já usado no resto do schema, não uma mudança de modelo). `TENANT_SCOPED_MODELS` atualizado com as 7 tabelas. `ModalidadesService`/`FeriadosService` + controllers completos (CRUD, mesmo padrão de `PlanosService`), sob um novo `AgendaModule` agregador registrado em `AppModule`. Acesso restrito a `ACADEMIA_ADMIN`/`RECEPCIONISTA` — sem leitura liberada pra `PROFESSOR` (diferente de Planos, que libera leitura; decisão de acesso já confirmada na análise). 19 testes e2e novos (Modalidade + Feriado: CRUD, unicidade por academia, isolamento de tenant, 401/403, soft delete) — 213 e2e + 114 unit no total do backend, todos verdes. `docs/02-banco-de-dados.md` atualizado (Módulo 4 MS1 "Implementado"; seção "Modelagem planejada" do Agenda reescrita para refletir o modelo de 5 entidades restantes — `Turma`/`Recorrencia`/`Aula`/`TurmaAluno`/`AulaAluno` — que entram nos MS seguintes).
- **2026-07-13, MS2**: camada de dados frontend — `Modalidade`/`Feriado` em `shared_core` (`packages/shared_core/lib/src/agenda/`), providers registrados. `ModalidadesApi`/`FeriadosApi` são CRUD puro sobre `CrudApi<T>`, zero método próprio (mesmo caso de `PlanosApi` — `list`/`get`/`create`/`update`/`updateStatus`/`remove` já cobrem 100% dos dois endpoints do MS1). `FeriadosApi` documenta que `updateStatus`/`status` de `list()` continuam herdados mas não se aplicam (Feriado não tem campo de status) — mesmo padrão de membro herdado sem uso já registrado em `MensalidadesApi`/`LancamentosApi`. Nenhuma abstração nova, nenhuma API de `Turma`/`Recorrencia`/`Aula` antecipada (schema já existe desde o MS1, mas sem service/controller/model até seus MS respectivos). Sem tela ainda — `flutter analyze` limpo nos 3 pacotes (`shared_core`, `admin_web`, `student_web`), `flutter test` 27/27 (nenhum teste novo esperado pra models/APIs, mesma convenção já estabelecida).
- **2026-07-13, MS3**: CRUD completo de `Turma`, backend e frontend. Seção "O papel de `Turma` no domínio" (acima, item 2) documentada antes de qualquer código, conforme pedido — reforça que este MS entrega **só** o agrupamento lógico, nada de horário/recorrência/aula/matrícula. Backend: `TurmasService`/`TurmasController` seguindo o padrão de `MatriculasService` — validação de existência de `modalidadeId`/`professorId` antes de criar/atualizar (`NotFoundException` se não existir ou pertencer a outra academia), enriquecimento de leitura (`turmaInclude`/`TurmaComRelacoes`) pra expor `modalidadeNome`/`professorNome` sem N+1 no frontend. 12 testes e2e novos (CRUD, FK inexistente, FK de outra academia, isolamento de tenant, soft delete) — 225 e2e + 114 unit no total, todos verdes. Frontend: `TurmasApi` (CrudApi puro, zero método próprio, mesma nota de não antecipar Recorrência/Aula/matrícula); `TurmasScreen`/`TurmaFormScreen`/`TurmaDetailScreen` espelham exatamente `PlanosScreen`/`PlanoFormScreen`/`PlanoDetailScreen` — única diferença deliberada: `modalidadeId`/`professorId` continuam `AppSelect` editáveis também em modo edição (ao contrário de `MatriculaFormScreen`, onde `alunoId`/`planoId` viram campo desabilitado), porque `UpdateTurmaDto` aceita essa troca sem quebrar nenhuma invariante do domínio. `TurmaDetailScreen` traz três seções `EmptyState.comingSoon` (Recorrências → MS4, Alunos matriculados → MS5, Aulas → MS6). `ModalidadesScreen` implementada como diálogo (`_NovaModalidadeDialog`/`_AcoesModalidadeDialog`, mesmo chassi de `_NovoLancamentoDialog` do Caixa) em vez de rotas próprias — só 2 campos (nome, cor), desproporcional pra uma tela cheia. Sidebar (`AppShell`) ganhou "Modalidades" e "Turmas" no lugar do placeholder desabilitado "Agenda"; novas rotas em `app_router.dart` (`/agenda/modalidades`, `/agenda/turmas` + `novo`/`:id`/`:id/editar`, com `key: ValueKey` nas duas últimas). Dois novos tokens em `AppIcons` (`turmas`, `modalidade`), nenhum componente novo do Design System. `flutter analyze` limpo em `shared_core` e `admin_web`. Validação manual via Playwright contra o build de produção (`flutter build web` servido estaticamente, autenticado com o usuário seed `admin@academiademo.com`): todos os 5 estados da lista de Turmas e Modalidades (loading, erro, vazio, vazio-filtrado, populado), fluxos de criar/editar/ativar-inativar/remover em ambas, desktop e mobile — nenhuma regressão encontrada.
- **2026-07-13, MS4**: CRUD completo de `Recorrencia`, sempre aninhado numa Turma. As duas invariantes pedidas (seção 2 item 3, acima) documentadas antes de qualquer código: Recorrência pertence exclusivamente à Turma (nunca ao Professor — `professorId` é só um override pontual) e uma Turma pode ter múltiplas Recorrências independentes. Backend: rota nunca de topo próprio, sempre `agenda/turmas/:turmaId/recorrencias` (create/list) e `agenda/turmas/:turmaId/recorrencias/:id` (update/remove) — a própria URL reforça a invariante 1; `findOrThrow` exige `{ id, turmaId }` juntos, então editar/remover uma Recorrência pela Turma errada dá 404 mesmo que o `id` exista e pertença à mesma academia (reforça a invariante em runtime, não só na modelagem). Validação condicional do campo por `tipo` (`diaSemana`/`diaDoMes`/`intervaloDias`) via `@ValidateIf` no `CreateRecorrenciaDto` (create sempre manda `tipo`) e verificação equivalente no service pra `update` parcial (quando `tipo` não é reenviado, mescla com o valor já persistido antes de validar — não dá pra expressar isso só com decorators numa atualização parcial). Nenhuma `AuditAction` nova — `RECORRENCIA_CREATED/UPDATED/DELETED` já existiam desde o MS1. 18 testes e2e novos (CRUD dos 3 tipos, campo obrigatório ausente por tipo, formato de `horaInicio`, FK de turma/professor inexistente ou de outra academia, múltiplas recorrências numa turma, mudança de tipo sem o novo campo obrigatório, a invariante 1 em runtime, isolamento de tenant, soft delete) — 243 e2e + 114 unit no total, todos verdes. Frontend: `RecorrenciasApi` deliberadamente **não estende** `CrudApi<T>` — sem paginação (lista cabe inteira numa Turma) e sem `status: UserStatus` (usa `ativo: bool` simples); forçar o encaixe exigiria um filtro/paginação que não fazem sentido aqui. Isso resolve, na prática, o que a nota `project_saasgym_crudapi_updatestatus_debt` pedia pra revisar quando surgisse uma 2ª entidade parecida — a conclusão é que Recorrência **confirma**, não refuta, que uma classe própria é o caminho certo quando a entidade não tem paginação/status no molde de `CrudApi<T>`. UI gerenciada inteiramente dentro de `TurmaDetailScreen` (`_RecorrenciasSection`/`_RecorrenciaFormDialog`/`_AcoesRecorrenciaDialog`), sem tela nem rota própria — mesmo raciocínio de diálogo-em-vez-de-rota já usado pra Modalidade, agora também documentando por que faz sentido aqui (a Recorrência só existe no contexto de uma Turma aberta, nunca navegada isoladamente). Campo condicional ao `tipo` no diálogo espelha a validação do backend. Nenhum componente novo do Design System. `flutter analyze` limpo em `shared_core`/`admin_web`. Validação manual via Playwright (build de produção): criar as 3 variações de tipo, editar, inativar, remover, mobile — todos os fluxos confirmados visualmente sem regressão. Achado de validação: `AppSelect` não expõe `aria-label` na árvore de acessibilidade do Flutter Web (mesmo achado já registrado em docs/15, Módulo 3 MS3/MS5) — interação automatizada com os dropdowns de `Tipo`/`Dia da semana` precisou ser por coordenada de clique lida do screenshot real, não por locator de texto/role.
- **2026-07-13, MS5**: CRUD completo de `TurmaAluno` — inscrição/desinscrição de aluno na Turma. As três invariantes pedidas (seção 2 item 6, acima) documentadas antes de qualquer código: `TurmaAluno` representa só a inscrição permanente (nada de dado por ocorrência); nunca cria/altera/remove `AulaAluno`; `AulaAluno` só nasce no gerador do MS6. **Bug real encontrado e corrigido durante a implementação**: o schema do MS1 tinha `@@unique([turmaId, alunoId])` em `TurmaAluno`, o que entraria em conflito direto com a própria seção 2 item 6 ("se voltar depois, é uma nova linha") e com a decisão desta sprint de que "sair da turma" é `status = INATIVO` (não `deletedAt` — item 11) — a constraint bloquearia permanentemente uma reinscrição depois de qualquer saída, porque a linha `INATIVO` continua existindo com `deletedAt = null`. Corrigido (migration `20260713183936_modulo4_ms5_turma_aluno`): removida a unique constraint, adicionado `@@index([turmaId])`; a regra "só uma inscrição ATIVA por vez" passa a ser validada no service (`garantirSemInscricaoAtiva`), mesmo padrão já usado para "uma Matricula ATIVA por aluno" (`docs/16`, item 1) — confirmado por teste e2e dedicado (reinscrição depois de sair cria uma nova linha sem erro). **Consequência de escopo derivada da invariante 3** (não uma nova decisão de negócio, uma leitura direta do que já foi pedido): como capacidade excedente era descrita em `docs/18` (seção 7, item 2) como "vira uma linha de `AulaAluno` com `FILA_ESPERA`", e este MS não pode tocar `AulaAluno`, exceder a capacidade neste MS apenas bloqueia a inscrição (409) — fila de espera de verdade fica para quando `AulaAluno` existir (MS6 em diante). Elegibilidade (`Matricula.status = ATIVA`) resolvida automaticamente no service a partir do `alunoId` — o DTO não pede `matriculaId` (só pode haver uma ATIVA por aluno, pedir para escolher seria redundante). Endpoints sempre aninhados (`agenda/turmas/:turmaId/alunos`), mesmo critério de `Recorrencia`. Novo `AuditAction` (`TURMA_ALUNO_STATUS_CHANGED`, mesma migration) — `TURMA_ALUNO_MATRICULADO`/`TURMA_ALUNO_REMOVIDO` já existiam desde o MS1. 15 testes e2e novos (CRUD, elegibilidade, duplicidade, reinscrição após saída, capacidade máxima e ilimitada, FK inexistente/cross-tenant, a invariante de não tocar `AulaAluno` verificada por contagem direta no banco, isolamento de tenant, soft delete) — 258 e2e + 114 unit no total, todos verdes. Frontend: `TurmaAlunosApi` também não estende `CrudApi<T>` (mesmo critério de `RecorrenciasApi`) — usa `UserStatus` mas via `/status` dedicado, sem `update()` genérico (não há outro campo editável). UI embutida em `TurmaDetailScreen` (`_AlunosMatriculadosSection`/`_NovaInscricaoDialog`/`_AcoesTurmaAlunoDialog`), sem tela nem rota própria; contador "N de M vagas ocupadas" só aparece quando `capacidadeMaxima` não é nula. `AppListTile` reutilizado para as linhas (aluno é o 1º caso de "pessoa" real dentro de um diálogo/seção da Agenda). Nenhum componente novo do Design System. `flutter analyze` limpo em `shared_core`/`admin_web`. Validação manual via Playwright: inscrição, tentativa de duplicidade (erro inline), sair da turma, reativar, remover, mobile — todos os fluxos confirmados visualmente sem regressão.
- **2026-07-13, MS6**: gerador de Aulas. As duas invariantes pedidas (seção 5, "Geração de Aulas", acima) documentadas antes de qualquer código: o gerador nunca altera registro existente, só cria o que falta (`Aula` já criada é fato histórico, imune a mudanças futuras em Turma/Recorrência/Professor/TurmaAluno); e a geração é determinística/idempotente (rodar de novo sobre o mesmo período nunca duplica `Aula`, nunca recria/duplica `AulaAluno`, nunca troca professor/horário de aula já gerada). Cálculo de datas extraído para `aulas.util.ts` (`calcularDatasCandidatas`), testável isoladamente — 9 testes unitários novos (SEMANAL/MENSAL/INTERVALADA, vigência clampando o período pedido, mês sem o dia configurado não gera nem "rola" pro mês seguinte, âncora do INTERVALADA sempre em `dataInicioVigencia`, idempotência do cálculo em si) — 123 unit no total. Algoritmo: para cada `Recorrencia` ativa da Turma, calcula datas candidatas na vigência efetiva, remove datas com `Feriado`, e só cria `Aula` (+ um `AulaAluno(MATRICULADO)` por `TurmaAluno` ativo) para datas sem `Aula` existente — a checagem de existência ignora `deletedAt` de propósito (mesmo uma Aula corrigida por engano ocupa a combinação `(recorrenciaId, data)`; recriar nesse caso é decisão manual fora deste gerador), e a constraint `@@unique([recorrenciaId, data])` (já existente desde o MS1) é a garantia de última instância. Diferente do bug corrigido no MS5 (`TurmaAluno`), esta unique constraint está correta aqui — não existe motivo de negócio pra ter duas `Aula` na mesma data/recorrência, então não foi alterada. Escopo deliberadamente restrito ao que o "Plano de micro-sprints" descreve como MS6 ("o algoritmo de geração em si"): só `POST .../aulas/gerar` (retorna `{geradas, jaExistentes}`) e `GET .../aulas` (paginado, com filtro de período) — cancelamento, professor substituto e aula extra ficam pro MS7 (Calendário), por isso não há `PATCH`/`DELETE` de Aula neste MS. 15 testes e2e novos (geração dos 3 tipos, snapshot correto de horário/professor/capacidade, override de professor da Recorrência, Feriado pulado, população de `AulaAluno` só para `TurmaAluno` ativos, idempotência rodando a geração duas vezes byte a byte — mesmos ids, mesmos `updatedAt`, mesma contagem —, geração parcial sobreposta só cria o delta, a invariante 1 verificada trocando o professor titular depois de gerar e conferindo que aulas já geradas não mudam, validação de período, paginação/filtro, isolamento de tenant) — 273 e2e no total, todos verdes. Frontend: `AulasApi` também não estende `CrudApi<T>` (mesmo critério de `RecorrenciasApi`/`TurmaAlunosApi`) mas **usa** `PaginatedResult<Aula>` — é a 1ª entidade aninhada da Agenda que cresce sem limite (uma linha por ocorrência) e por isso precisa de paginação de verdade, ao contrário de Recorrência/TurmaAluno. Seção "Aulas" embutida em `TurmaDetailScreen` (`_AulasSection`/`_GerarAulasDialog`), com `AppPagination` reutilizado — 1º caso na Agenda de uma seção embutida paginada. Diálogo de geração devolve o resultado (não só `bool`) pra mostrar quantas aulas foram criadas via `SnackBar`. Linhas de Aula são só leitura nesta fase (sem diálogo de ações — reforça o escopo restrito a geração). Nenhum componente novo do Design System. `flutter analyze` limpo em `shared_core`/`admin_web`. Validação manual via Playwright: gerar aulas (janela padrão de 30 dias pré-preenchida), conferir snapshot nas linhas geradas, rodar a geração de novo confirmando idempotência visualmente ("Nenhuma aula nova — todo o período já estava gerado."), mobile — sem regressão.
- **2026-07-13, MS7**: Calendário — uma visão operacional sobre `Aula`, nunca uma entidade própria (docs/18, seção 5, "Calendário"). As quatro invariantes pedidas documentadas antes de qualquer código: `Aula` continua o único fato do calendário (nenhuma tabela nova); cancelar nunca remove, só muda `status`; professor substituto é exceção pontual só de `Aula.professorId`, nunca toca Turma/Recorrência; aula extra é sempre uma `Aula` independente (`recorrenciaId = null`), nunca cria/altera `Recorrencia`. Consequência de escopo direta (não uma nova decisão): nenhuma das operações do MS7 popula `AulaAluno` automaticamente — diferente do gerador do MS6, aula extra nasce sem alunos, população fica pra quando um caso real pedir. Backend: `AulasService` estendido com `cancelar`/`definirSubstituto`/`criarExtra`/`remove`/`findOne`/`listCalendario`; novo controller de topo `agenda/aulas` (não aninhado — Calendário cruza turmas por natureza: filtro por professor/status/modalidade não faz sentido preso a uma Turma), convivendo com o controller aninhado do MS6 (`agenda/turmas/:turmaId/aulas`, inalterado). `AulaResponseDto` ganhou `turmaNome`/`modalidadeId`/`modalidadeNome` (enriquecimento pro filtro/exibição cross-turma). Endpoint de listagem já nasce com os 4 filtros previstos desde a análise (seção 7) + paginação (`pageSize` até 200, maior que o padrão de 100, pensado pra visão mensal). "Definir substituto" bloqueado numa aula cancelada (400) — regra nova, de bom senso, não pedida explicitamente mas de baixo risco. Nenhuma `AuditAction` nova — `AULA_CANCELADA`/`AULA_SUBSTITUICAO`/`AULA_EXTRA_CRIADA`/`AULA_DELETED` já existiam desde o MS1. 15 testes e2e novos (cancelar preservando histórico, substituto sem tocar Turma/Recorrência, bloqueio de substituto em aula cancelada, aula extra com/sem override e sem criar Recorrência, os 4 filtros combinados, soft delete, isolamento de tenant) — 288 e2e + 123 unit no total, todos verdes. Frontend: `CalendarScreen` — dia/semana/mês construídos só com composição local sobre componentes já existentes (`AppCard`/`AppButton`/`AppBadge`/`AppSelect`/`AppDateField`/`Divider`/`EmptyState`/`LoadingSkeleton`), nenhum componente novo do Design System; mês é uma grade de 7 colunas com dias fora do mês esmaecidos e um "+N mais" quando uma célula tem mais aulas do que cabe. Ao tocar numa Aula, `_AulaAcoesDialog` (visualizar/cancelar/substituto, chassi multi-view como `_AcoesRecorrenciaDialog`) — sem tela de detalhe própria, mesmo padrão contextual de todo o Módulo 4; menu se adapta ao status (aula cancelada só mostra "Remover", sem "Cancelar"/"Definir substituto"). "Nova aula extra" é um botão de topo (não uma ação por aula), pré-preenchido com a data em foco no calendário. `flutter analyze` limpo em `shared_core`/`admin_web`. Validação manual via Playwright: mês/semana/dia, cancelamento com motivo (aula cancelada aparece riscada no calendário, histórico íntegro), professor substituto, aula extra, filtros, mobile — sem regressão. Achado de validação: `AppTextField` com `maxLines > 1` renderiza como `<textarea>` sem `aria-label` (diferente do `<input>` de linha única, que herda o `aria-label` do grupo) — mesma categoria dos achados já registrados em docs/15 (Módulo 3/4) sobre limitações de acessibilidade do Flutter Web pra automação de teste. Pendência conhecida, fora deste MS: o card "Agenda do dia" do Dashboard continua `EmptyState.comingSoon` — já poderia reusar `AulasApi` pra mostrar as aulas de hoje, mas isso não foi pedido nesta sprint e fica como próxima oportunidade.
- **2026-07-13, MS8**: Frequência — a presença pertence exclusivamente a `AulaAluno` (docs/18, seção 5, "Frequência"), último micro-sprint do Módulo 4. As quatro invariantes pedidas documentadas antes de qualquer código: presença mora só em `AulaAluno.presenca`, nunca em `Aula`/`Turma`/`Matricula`; registrar presença nunca escreve `Aula`/`Turma`/`Recorrencia`/`TurmaAluno` (só `AulaAluno`); só `Aula`s realizadas recebem presença (`status == AGENDADA && data < hoje`, mesmo cálculo de "realizada" de sempre — cancelada bloqueia sempre, hoje ainda não é "realizada"); frequência é fato histórico, imune a mudanças futuras em Matricula/Turma/Professor. Consequência de escopo direta: registrar/alterar presença é a mesma operação (sem histórico de mudanças de presença) — corrigir uma marcação errada é só chamar de novo com outro valor. Reposição e promoção de fila de espera continuam fora deste MS (não pedidas nesta sprint, já modeladas em `AulaAluno.tipo`/`reposicaoDeAulaAlunoId` desde o MS1). Backend: novo módulo `agenda/aula-alunos` — `GET agenda/aulas/:aulaId/alunos` (consulta por Aula), `PATCH agenda/aulas/:aulaId/alunos/:id/presenca` (registrar/alterar), `GET agenda/alunos/:alunoId/frequencia` (histórico cross-aula, paginado, filtro de período) — todas dentro do mesmo `AgendaModule`. Nenhuma migration — schema (`AulaAluno.presenca`, enum `PresencaStatus` com `JUSTIFICADA`) e `AuditAction.AULA_ALUNO_PRESENCA_MARCADA` já existiam desde o MS1, exatamente como planejado quando esses campos foram antecipados. 14 testes e2e novos (registrar e alterar presença, falta justificada, bloqueio em aula cancelada/futura/de hoje, `AulaAluno` de outra aula rejeitado por 404 — mesmo padrão de `{id, aulaId}` conferidos juntos já usado em Recorrencia/TurmaAluno —, invariante de não tocar Aula/Turma/TurmaAluno verificada por `updatedAt` inalterado, consulta por Aula, consulta por Aluno ordenada por data desc, isolamento de tenant) — 302 e2e + 123 unit no total, todos verdes. Frontend: `AulaAlunosApi` também não estende `CrudApi<T>` (mesmo critério das outras APIs aninhadas da Agenda) — `registrarPresenca` é deliberadamente uma única chamada pra criar e alterar, sem distinção. Frequência **não** ganhou tela nem seção própria — vive dentro do `_AulaAcoesDialog` do `CalendarScreen` (MS7), como uma 4ª view (`menu → frequencia`), com o botão "Registrar frequência" só aparecendo quando a aula selecionada já está realizada (mesmo cálculo do backend, replicado no frontend). Cada aluno vira uma linha com um único `AppSelect<PresencaStatus?>` que salva no próprio `onChanged` — sem botão de salvar por linha, como uma planilha de chamada. Nenhum componente novo do Design System. `flutter analyze` limpo em `shared_core`/`admin_web`. Validação manual via Playwright: aula realizada mostra "Registrar frequência", aula cancelada e aula futura não mostram, marcar Presente e depois trocar pra Falta justificada persistem corretamente, mobile — sem regressão.

**Módulo 4 (Agenda) completo — MS1 a MS8 entregues + Sprint de Consolidação concluída** (2026-07-13, incluindo a revisão de performance da geração de aulas prevista desde a aprovação do plano — ver `docs/19-sprint-consolidacao.md`). Projeto aprovado para iniciar o próximo módulo do roadmap (`docs/08-roadmap.md`) — Módulo 5, Avaliação Física.
