import { ApiProperty } from '@nestjs/swagger';
import { RecorrenciaTipo } from '@prisma/client';

export class RecorrenciaResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  turmaId!: string;

  @ApiProperty({ enum: RecorrenciaTipo })
  tipo!: RecorrenciaTipo;

  @ApiProperty({ nullable: true })
  diaSemana!: number | null;

  @ApiProperty({ nullable: true })
  diaDoMes!: number | null;

  @ApiProperty({ nullable: true })
  intervaloDias!: number | null;

  @ApiProperty()
  horaInicio!: string;

  @ApiProperty()
  duracaoMinutos!: number;

  @ApiProperty({ nullable: true })
  professorId!: string | null;

  @ApiProperty({ nullable: true, description: 'Nulo quando não há override — usa o titular da Turma' })
  professorNome!: string | null;

  @ApiProperty()
  dataInicioVigencia!: Date;

  @ApiProperty({ nullable: true })
  dataFimVigencia!: Date | null;

  @ApiProperty()
  ativo!: boolean;

  @ApiProperty()
  createdAt!: Date;
}
