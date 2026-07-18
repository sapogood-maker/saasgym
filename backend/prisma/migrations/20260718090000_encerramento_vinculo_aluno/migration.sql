-- Auditoria do ciclo de vida do Aluno (docs/32) — arquivar/remover um
-- Aluno passa a encerrar automaticamente seu vínculo com a academia
-- (Matrícula, TurmaAluno, reposições pendentes), preservando todo
-- histórico. Dois valores de enum novos, só usados por esse cascade:
--
-- `MotivoCancelamento.ALUNO_ARQUIVADO` — nunca escolhido manualmente na
-- UI, categoriza o cancelamento de Matrícula feito pelo cascade (não é
-- "academia cancelou" uma decisão isolada — é consequência de arquivar o
-- aluno), pra não distorcer os relatórios de motivo de churn.
--
-- `AuditAction.ALUNO_VINCULO_ENCERRADO` — um registro de auditoria só,
-- resumindo o cascade inteiro (matrícula cancelada, turmas desativadas,
-- aulas futuras removidas, reposições rejeitadas).
ALTER TYPE "MotivoCancelamento" ADD VALUE 'ALUNO_ARQUIVADO';
ALTER TYPE "AuditAction" ADD VALUE 'ALUNO_VINCULO_ENCERRADO';
