# Banco de Dados

PostgreSQL + Prisma ORM. Schema em `backend/prisma/schema.prisma`, migrations em `backend/prisma/migrations/`.

## Implementado (Sprints 0-3, Módulo 1, Módulo 2, Módulo 3, Módulo 4 completo, Módulo 5 completo, Sprint 6 completo)

`Academia` (tenant), `User` (identidade de login), `RefreshToken`, `AuditLog`, `PlanoSaas`, `AcademiaConfiguracao`, `Arquivo`, `Aluno`, `Professor`, `Plano`, `Matricula`, `Mensalidade`, `Lancamento`, `Modalidade`, `Feriado`, `Turma`, `Recorrencia`, `Aula`, `TurmaAluno`, `AulaAluno`, `AvaliacaoFisica`, `SolicitacaoReposicao`, `Notificacao`. Ver `backend/prisma/schema.prisma` para os campos exatos.

- `Academia.status`: `TRIAL | ATIVA | SUSPENSA | BLOQUEADA | CANCELADA` (Sprint 2 — os três últimos bloqueiam login/refresh, ver `docs/13-admin-saas.md`). `Academia.dominio` (subdomínio futuro, sem uso ainda) e `Academia.trialExpiresAt` também são do Sprint 2. `Academia.planoSaasId` é obrigatório — toda academia referencia um `PlanoSaas`.
- `User.academiaId` é **nulo apenas** para `role = SYSTEM_ADMIN`. `User.passwordChangedAt` (Sprint 1) registra a última troca de senha. `User.fotoArquivoId` (Sprint 3) — avatar do próprio usuário, distinto da foto de `Aluno`/`Professor` (um `ACADEMIA_ADMIN` não é necessariamente um `Professor` cadastrado).
- `RefreshToken` guarda o **hash** do token (SHA-256, nunca o token em texto puro), com `revokedAt`/`replacedBy` para rotação e revogação, e `ipAddress`/`userAgent`/`lastUsedAt` (Sprint 1) — cada linha é, na prática, uma sessão (ver `docs/10-auth.md`).
- `AuditLog` (Sprint 1, +6 ações no Sprint 2, +11 ações no Sprint 3, +4 no Módulo 2, +7 no Módulo 3) — trilha de auditoria (`AuditAction`: eventos de autenticação do Sprint 1; `ACADEMIA_*`/`PLANO_SAAS_*` do Sprint 2; `ALUNO_*`/`PROFESSOR_*`/`USER_PROFILE_UPDATED`/`FOTO_UPLOADED` do Sprint 3; `PLANO_*` do Módulo 1; `MATRICULA_*` do Módulo 2; `MENSALIDADE_*`/`LANCAMENTO_*` do Módulo 3), sem FK obrigatória para `User` (login falho pode não corresponder a nenhum usuário real — usa `identifier` para guardar o e-mail tentado).
- `PlanoSaas` (Sprint 2) — catálogo comercial do SaaS (Free/Trial/Basic/Professional/Enterprise), não tenant-scoped. Campos `limite*` nullable (`null` = ilimitado), sem enforcement ainda. Nome deliberadamente distinto do `Plano` de negócio (tenant-scoped, Módulo 1), para nunca colidir.
- `AcademiaConfiguracao` (Sprint 2) — branding 1:1 com `Academia` (separado do cadastro administrativo por ser um tipo de dado diferente).
- `Arquivo` (Sprint 2) — metadados de qualquer upload via `StorageProvider` (nome original, nome físico em UUID, caminho, mime type, tamanho, provider). Ponto único reaproveitável por qualquer módulo futuro com upload.
- `Aluno`/`Professor` (Sprint 3, tenant-scoped) — cadastro administrativo (sem login próprio ainda). `@@unique([academiaId, cpf])`: CPF normalizado (só dígitos) e único dentro da academia, não globalmente. `deletedAt` (soft delete, filtrado no service, não na extensão do Prisma). `fotoArquivoId` → `Arquivo`. Ver `docs/14-alunos-professores.md`.
- `Plano` (Módulo 1, tenant-scoped) — mensalidade que a academia vende ao aluno. Ver `docs/15-design-system-e-padrao-crud.md`.
- `Matricula` (Módulo 2, tenant-scoped) — vincula `Aluno` a `Plano` por um período, ciclo de vida completo (`ATIVA`/`TRANCADA`/`CANCELADA`/`ENCERRADA`). Ver `docs/16-modulo-2-matriculas-analise.md`.
- `Mensalidade`/`Lancamento` (Módulo 3, tenant-scoped) — cobrança mensal gerada sob demanda a partir de `Matricula`, e receita/despesa manual independente. Ver `docs/17-modulo-3-financeiro-analise.md`.
- `Modalidade`/`Feriado`/`Turma`/`Recorrencia`/`Aula`/`TurmaAluno`/`AulaAluno` (Módulo 4, tenant-scoped, MS1-MS8 — schema completo desde o MS1, services entregues incrementalmente) — Agenda completa: `Modalidade` (categoria de aula, nome/cor) e `Feriado` (cancela aulas geradas automaticamente na data); `Turma` (o grupo — nome, modalidade, professor titular, capacidade máxima, local); `Recorrencia` (quando as aulas de uma Turma acontecem — semanal/mensal/intervalada, uma linha por padrão); `Aula` (ocorrência concreta numa data, gerada de uma `Recorrencia` como snapshot de horário/professor/capacidade, ou avulsa como "aula extra"); `TurmaAluno` (vínculo permanente aluno↔turma, exige `Matricula` ATIVA); `AulaAluno` (vínculo por ocorrência — `tipo`: matriculado/fila de espera/reposição; `presenca`: presente/ausente/justificada, nullable). Ver `docs/18-modulo-4-agenda-analise.md`.
- `AvaliacaoFisica` (Módulo 5, tenant-scoped, completo MS1-MS3) — histórico de medidas corporais do aluno (`data`/`peso`/`altura`), sempre aninhada em `Aluno` (`alunos/:alunoId/avaliacoes-fisicas`, sem coleção de topo). Fato histórico imutável — sem `update`, só `create`/soft-delete (corrigir erro de cadastro = apagar + recriar). IMC nunca é armazenado, sempre calculado (`peso / (altura/100)²`). Sem vínculo com `Professor` — autoria via `createdByUserId`, mesmo campo de todo o resto do produto. Ver `docs/20-modulo-5-avaliacao-fisica-analise.md`.
- `SolicitacaoReposicao` (Sprint 6 — Agenda Avançada, tenant-scoped, MS1) — pedido de reposição de uma aula perdida (falta ou cancelamento), sempre nascendo sem aula de destino (`aulaDestinoId` nulo até a aprovação). Aprovar é o único caminho que cria um `AulaAluno(tipo=REPOSICAO)` — nunca um atalho direto — com recontagem de capacidade em tempo real dentro de uma transação.
- `Notificacao` (Sprint 6, tenant-scoped, MS2) — canal interno do `NotificationProvider` (interface desacoplada, mesmo desenho de `StorageProvider`, pronta pra e-mail/WhatsApp/push futuros — só o canal interno existe nesta sprint). Sempre dirigida a um `User` específico. Marcar como lida nunca gera `AuditLog`. Ver `docs/21-sprint6-agenda-avancada-analise.md`.

## Modelagem planejada

Entidades marcadas com 🏢 têm `academiaId` obrigatório. As demais são globais/sistema. Sequência de sprints em `docs/08-roadmap.md` (não fixada aqui para não duplicar/desatualizar).

**Treinos** 🏢 (estrutura apenas — sem IA)
- `Exercicio` — catálogo (nome, grupo muscular, descrição, foto/vídeo); `academiaId` nullable permite catálogo global + customizações por academia.
- `Treino` — plano de treino atribuído a um aluno por um professor.
- `TreinoExercicio` — join `Treino`↔`Exercicio` com ordem, séries, repetições, carga, observações.

**Avisos** 🏢
- `Aviso` — comunicado (todos ou aluno específico).
- `AvisoLeitura` — controle de leitura por aluno.

**Backup** (sistema — não tenant-scoped)
- `BackupJob` — histórico de execuções.
- `BackupConfig` — provider e credenciais ativos.

## Princípios de modelagem

- Nenhum campo redundante: dados de aluno/professor ficam nas tabelas de domínio, não duplicados em `User`.
- Toda entidade de negócio referencia `academiaId` diretamente, permitindo índice composto simples em tabelas de alto volume — essencial para performance com centenas de tenants no mesmo banco.
- `Turma`/`Aula`/`AulaAluno` e `Plano`/`Matricula`/`Mensalidade` evitam "god tables", permitindo evoluir cada conceito independentemente.

## Fluxo de trabalho com migrations

```bash
cd backend
npx prisma migrate dev --name <descricao>   # cria e aplica uma migration em dev
npx prisma migrate deploy                    # aplica migrations pendentes (produção — já roda automaticamente no start do container)
npx prisma studio                             # explorar os dados
npm run prisma:seed                           # popular dados iniciais (system admin + academia demo)
```
