import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { UserStatus } from '@prisma/client';
import { IsEnum, IsOptional, IsString } from 'class-validator';

/// Mesmo formato de `UpdateTurmaStatusDto`. `INATIVO` representa "aluno
/// saiu da turma" — encerramento de negócio (docs/18, seção 3 item 11),
/// não `deletedAt`. Reinscrever depois pode reativar esta mesma linha ou
/// criar uma nova via POST — as duas formas coexistem, sem constraint que
/// force uma ou outra.
export class UpdateTurmaAlunoStatusDto {
  @ApiProperty({ enum: UserStatus })
  @IsEnum(UserStatus)
  status!: UserStatus;

  @ApiPropertyOptional({ description: 'Vai para o metadata da auditoria' })
  @IsOptional()
  @IsString()
  motivo?: string;
}
