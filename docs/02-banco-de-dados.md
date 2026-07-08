# Banco de Dados

PostgreSQL + Prisma ORM. Schema em `backend/prisma/schema.prisma`, migrations em `backend/prisma/migrations/`.

## Implementado (Sprint 0 + Sprint 1)

`Academia` (tenant), `User` (identidade de login), `RefreshToken`, `AuditLog`. Ver `backend/prisma/schema.prisma` para os campos exatos.

- `Academia.status`: `TRIAL | ATIVA | INATIVA`.
- `User.academiaId` é **nulo apenas** para `role = SYSTEM_ADMIN`. `User.passwordChangedAt` (Sprint 1) registra a última troca de senha.
- `RefreshToken` guarda o **hash** do token (SHA-256, nunca o token em texto puro), com `revokedAt`/`replacedBy` para rotação e revogação, e `ipAddress`/`userAgent`/`lastUsedAt` (Sprint 1) — cada linha é, na prática, uma sessão (ver `docs/10-auth.md`).
- `AuditLog` (Sprint 1) — trilha de eventos de autenticação (`AuditAction`: `LOGIN_SUCCESS`, `LOGIN_FAILURE`, `LOGOUT`, `PASSWORD_CHANGED`, `REFRESH_TOKEN_USED`, `REFRESH_TOKEN_REUSE_DETECTED`, `SESSION_REVOKED`), sem FK obrigatória para `User` (login falho pode não corresponder a nenhum usuário real — usa `identifier` para guardar o e-mail tentado).

## Modelagem planejada (sprints seguintes)

Entidades marcadas com 🏢 têm `academiaId` obrigatório. As demais são globais/sistema.

**Pessoas** 🏢 (Sprint 2)
- `Aluno` — foto, nome, CPF, telefone, WhatsApp, e-mail, nascimento, endereço, observações, status; `userId` opcional (1:1) para login no portal.
- `Professor` — cadastro completo; `userId` opcional (1:1).

**Planos e Modalidades** 🏢 (Sprint 3)
- `Plano` — tipo (mensal/trimestral/semestral/anual/personalizado), valor, duração, quantidade de aulas, dias permitidos, limite de reposições.
- `Modalidade` — nome, descrição, cor.
- `Matricula` — vincula `Aluno` a um `Plano` em um período; base para geração de mensalidades.

**Agenda** 🏢 (Sprints 4-5) — três camadas para separar recorrência, ocorrência e inscrição:
- `Turma` — horário recorrente (dia da semana, hora, professor, modalidade, capacidade máxima). É o template.
- `Aula` — ocorrência concreta em uma data, gerada de uma `Turma` ou avulsa.
- `AulaAluno` — vínculo aluno↔aula (`tipo`: matriculado/fila de espera/reposição; `presenca` nullable).
- `SolicitacaoAgenda` — pedido de troca de horário ou reposição, com fluxo de aprovação.

**Financeiro** 🏢 (Sprint 6)
- `Mensalidade` — cobrança periódica derivada de `Matricula`/`Plano` (valor, vencimento, pagamento, status, forma de pagamento, desconto).
- `Lancamento` — receitas/despesas manuais, opcionalmente ligadas a uma `Mensalidade`.

**Treinos** 🏢 (Sprint 10, estrutura apenas — sem IA)
- `Exercicio` — catálogo (nome, grupo muscular, descrição, foto/vídeo); `academiaId` nullable permite catálogo global + customizações por academia.
- `Treino` — plano de treino atribuído a um aluno por um professor.
- `TreinoExercicio` — join `Treino`↔`Exercicio` com ordem, séries, repetições, carga, observações.

**Avisos** 🏢 (Sprint 9)
- `Aviso` — comunicado (todos ou aluno específico).
- `AvisoLeitura` — controle de leitura por aluno.

**Backup** (Sprint 8, sistema — não tenant-scoped)
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
