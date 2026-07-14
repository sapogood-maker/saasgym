import { ApiProperty } from '@nestjs/swagger';
import { UserStatus } from '@prisma/client';

export class TurmaAlunoResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  turmaId!: string;

  @ApiProperty()
  alunoId!: string;

  @ApiProperty()
  alunoNome!: string;

  @ApiProperty()
  matriculaId!: string;

  @ApiProperty({ enum: UserStatus })
  status!: UserStatus;

  @ApiProperty()
  dataInicio!: Date;

  @ApiProperty({ nullable: true })
  dataFim!: Date | null;

  @ApiProperty()
  createdAt!: Date;
}
