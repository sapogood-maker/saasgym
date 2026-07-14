import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

/// `turmaId` não é campo do DTO — vem da rota
/// (`agenda/turmas/:turmaId/alunos`), mesmo critério de `Recorrencia`.
/// `matriculaId` também não é campo do DTO: o service resolve a
/// `Matricula` ATIVA do aluno automaticamente (elegibilidade) — pedir pro
/// operador escolher qual matrícula seria redundante, já que só existe
/// uma ATIVA por aluno por vez (`docs/16`, item 1).
export class CreateTurmaAlunoDto {
  @ApiProperty()
  @IsUUID()
  alunoId!: string;
}
