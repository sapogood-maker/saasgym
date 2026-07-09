# Banco de Dados

PostgreSQL + Prisma ORM. Schema em `backend/prisma/schema.prisma`, migrations em `backend/prisma/migrations/`.

## Implementado (Sprints 0-3)

`Academia` (tenant), `User` (identidade de login), `RefreshToken`, `AuditLog`, `PlanoSaas`, `AcademiaConfiguracao`, `Arquivo`, `Aluno`, `Professor`. Ver `backend/prisma/schema.prisma` para os campos exatos.

- `Academia.status`: `TRIAL | ATIVA | SUSPENSA | BLOQUEADA | CANCELADA` (Sprint 2 — os três últimos bloqueiam login/refresh, ver `docs/13-admin-saas.md`). `Academia.dominio` (subdomínio futuro, sem uso ainda) e `Academia.trialExpiresAt` também são do Sprint 2. `Academia.planoSaasId` é obrigatório — toda academia referencia um `PlanoSaas`.
- `User.academiaId` é **nulo apenas** para `role = SYSTEM_ADMIN`. `User.passwordChangedAt` (Sprint 1) registra a última troca de senha. `User.fotoArquivoId` (Sprint 3) — avatar do próprio usuário, distinto da foto de `Aluno`/`Professor` (um `ACADEMIA_ADMIN` não é necessariamente um `Professor` cadastrado).
- `RefreshToken` guarda o **hash** do token (SHA-256, nunca o token em texto puro), com `revokedAt`/`replacedBy` para rotação e revogação, e `ipAddress`/`userAgent`/`lastUsedAt` (Sprint 1) — cada linha é, na prática, uma sessão (ver `docs/10-auth.md`).
- `AuditLog` (Sprint 1, +6 ações no Sprint 2, +11 ações no Sprint 3) — trilha de auditoria (`AuditAction`: eventos de autenticação do Sprint 1; `ACADEMIA_CREATED`, `ACADEMIA_UPDATED`, `ACADEMIA_STATUS_CHANGED`, `ACADEMIA_CONFIGURACAO_UPDATED`, `PLANO_SAAS_CREATED`, `PLANO_SAAS_UPDATED` do Sprint 2; `ALUNO_*`, `PROFESSOR_*`, `USER_PROFILE_UPDATED`, `FOTO_UPLOADED` do Sprint 3), sem FK obrigatória para `User` (login falho pode não corresponder a nenhum usuário real — usa `identifier` para guardar o e-mail tentado).
- `PlanoSaas` (Sprint 2) — catálogo comercial do SaaS (Free/Trial/Basic/Professional/Enterprise), não tenant-scoped. Campos `limite*` nullable (`null` = ilimitado), sem enforcement ainda. Nome deliberadamente distinto do `Plano` de negócio planejado abaixo, para nunca colidir.
- `AcademiaConfiguracao` (Sprint 2) — branding 1:1 com `Academia` (separado do cadastro administrativo por ser um tipo de dado diferente).
- `Arquivo` (Sprint 2) — metadados de qualquer upload via `StorageProvider` (nome original, nome físico em UUID, caminho, mime type, tamanho, provider). Ponto único reaproveitável por qualquer módulo futuro com upload.
- `Aluno`/`Professor` (Sprint 3, tenant-scoped) — cadastro administrativo (sem login próprio ainda). `@@unique([academiaId, cpf])`: CPF normalizado (só dígitos) e único dentro da academia, não globalmente. `deletedAt` (soft delete, filtrado no service, não na extensão do Prisma). `fotoArquivoId` → `Arquivo`. Ver `docs/14-alunos-professores.md`.

## Modelagem planejada

Entidades marcadas com 🏢 têm `academiaId` obrigatório. As demais são globais/sistema. Sequência de sprints em `docs/08-roadmap.md` (não fixada aqui para não duplicar/desatualizar).

**Planos e Modalidades** 🏢
- `Plano` — plano de mensalidade que a academia vende ao aluno (mensal/trimestral/semestral/anual/personalizado), valor, duração, quantidade de aulas, dias permitidos, limite de reposições. **Não confundir com `PlanoSaas`** (já implementado, Sprint 2) — este é o plano comercial da própria academia para seus alunos, tenant-scoped.
- `Modalidade` — nome, descrição, cor.
- `Matricula` — vincula `Aluno` a um `Plano` em um período; base para geração de mensalidades.

**Agenda** 🏢 — três camadas para separar recorrência, ocorrência e inscrição:
- `Turma` — horário recorrente (dia da semana, hora, professor, modalidade, capacidade máxima). É o template.
- `Aula` — ocorrência concreta em uma data, gerada de uma `Turma` ou avulsa.
- `AulaAluno` — vínculo aluno↔aula (`tipo`: matriculado/fila de espera/reposição; `presenca` nullable).
- `SolicitacaoAgenda` — pedido de troca de horário ou reposição, com fluxo de aprovação.

**Financeiro** 🏢
- `Mensalidade` — cobrança periódica derivada de `Matricula`/`Plano` (valor, vencimento, pagamento, status, forma de pagamento, desconto).
- `Lancamento` — receitas/despesas manuais, opcionalmente ligadas a uma `Mensalidade`.

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
