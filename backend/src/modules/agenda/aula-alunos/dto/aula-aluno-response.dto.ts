import { ApiProperty } from '@nestjs/swagger';
import { AulaAlunoTipo, PresencaStatus } from '@prisma/client';

export class AulaAlunoResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  aulaId!: string;

  @ApiProperty()
  alunoId!: string;

  @ApiProperty()
  alunoNome!: string;

  @ApiProperty({ nullable: true })
  turmaAlunoId!: string | null;

  @ApiProperty({ enum: AulaAlunoTipo })
  tipo!: AulaAlunoTipo;

  @ApiProperty({ enum: PresencaStatus, nullable: true, description: 'Nulo = ainda não marcado' })
  presenca!: PresencaStatus | null;

  @ApiProperty()
  createdAt!: Date;
}
