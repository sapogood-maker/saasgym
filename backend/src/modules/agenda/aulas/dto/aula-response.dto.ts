import { ApiProperty } from '@nestjs/swagger';
import { AulaStatus } from '@prisma/client';

export class AulaResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  turmaId!: string;

  @ApiProperty()
  turmaNome!: string;

  @ApiProperty({ description: 'Para o filtro por modalidade no Calendário (MS7)' })
  modalidadeId!: string;

  @ApiProperty()
  modalidadeNome!: string;

  @ApiProperty({ nullable: true, description: 'Nulo = aula extra, sem recorrência por trás' })
  recorrenciaId!: string | null;

  @ApiProperty()
  data!: Date;

  @ApiProperty()
  horaInicio!: string;

  @ApiProperty()
  duracaoMinutos!: number;

  @ApiProperty()
  professorId!: string;

  @ApiProperty()
  professorNome!: string;

  @ApiProperty({ nullable: true, description: 'Nulo = ilimitada' })
  capacidadeMaxima!: number | null;

  @ApiProperty({ enum: AulaStatus })
  status!: AulaStatus;

  @ApiProperty({ nullable: true })
  motivoCancelamento!: string | null;

  @ApiProperty({ description: 'Quantidade de AulaAluno vinculados a esta aula' })
  totalAlunos!: number;

  @ApiProperty()
  createdAt!: Date;
}

export class PaginatedAulasResponseDto {
  @ApiProperty({ type: [AulaResponseDto] })
  items!: AulaResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  pageSize!: number;
}
