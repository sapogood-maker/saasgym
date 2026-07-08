# Roadmap

Cada sprint termina com o projeto compilando, rodando via Docker Compose local, e com o incremento documentado.

| Sprint | Entrega | Status |
|---|---|---|
| **0 — Fundação** | Estrutura de pastas; NestJS bootstrap + Swagger + health-check; Prisma inicial (`Academia`, `User`, `RefreshToken`); workspace Melos + `shared_core` skeleton; `docker-compose.yml` local; CI skeleton; docs base. | ✅ Concluído |
| **1 — Autenticação & Multi-tenant** | Módulo `auth` completo (login/refresh/logout, guards, decorators); `TenantContext` + filtro automático por `academiaId`; CRUD `Academias` (system admin); seed inicial; telas de login em `admin_web`/`student_web`. | Próximo |
| **2 — Alunos & Professores** | CRUD `Aluno` (com upload de foto via `StorageProvider`); CRUD `Professor`; telas de listagem/cadastro/edição no `admin_web`. | Planejado |
| **3 — Planos & Modalidades** | CRUD `Plano`, `Modalidade`; matrícula do aluno em um plano (`Matricula`). | Planejado |
| **4 — Agenda (núcleo)** | `Turma`, geração de `Aula`, `AulaAluno` (matrícula, capacidade máxima, fila de espera); tela de agenda semanal. | Planejado |
| **5 — Agenda avançada** | Reposições e `SolicitacaoAgenda` (troca de horário); interface `NotificationProvider` preparada (sem envio real). | Planejado |
| **6 — Financeiro** | Geração de `Mensalidade` a partir de `Matricula`; `Lancamento` (receita/despesa); fluxo de caixa, formas de pagamento, inadimplência. | Planejado |
| **7 — Dashboard** | Endpoints agregados (alunos ativos, agenda do dia, faturamento, vencidas, próximos vencimentos); tela dashboard. | Planejado |
| **8 — Backup** | `StorageProvider` finalizado + `GoogleDriveProvider`; módulo `backup` (pg_dump → zip → upload manual, histórico). | Planejado |
| **9 — Portal do Aluno (MVP)** | `student_web`: login, agenda, pagamentos (visualização), atualização de dados, presença, avisos, solicitar troca/reposição. | Planejado |
| **10 — Treinos (estrutura)** | CRUD `Exercicio`, `Treino`, `TreinoExercicio`; upload de foto/vídeo. Sem IA. | Planejado |
| **11 — Hardening & Deploy produção** | Testes automatizados; rate limiting; logging estruturado; CI/CD completo; deploy Coolify (staging + produção); revisão final da documentação. | Planejado |

## Decisões em aberto (não bloqueiam o início dos sprints correspondentes)

- **Gateway de pagamento** para "pagar mensalidade" pelo portal do aluno (ex.: Mercado Pago, Asaas) — a integração deve seguir o mesmo padrão de abstração usado em `StorageProvider` (interface + implementação plugável). A decidir antes do Sprint 9.
- **Canal real de notificações** (e-mail/WhatsApp/push) para o `NotificationProvider` do Sprint 5 — a interface é criada nesse sprint, a implementação concreta pode vir depois.
