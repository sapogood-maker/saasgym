import { ApiProperty } from '@nestjs/swagger';
import { AulaAlunoTipo, AulaStatus, PresencaStatus } from '@prisma/client';

export class FrequenciaAlunoResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  aulaId!: string;

  @ApiProperty()
  aulaData!: Date;

  @ApiProperty({ enum: AulaStatus })
  aulaStatus!: AulaStatus;

  @ApiProperty()
  turmaId!: string;

  @ApiProperty()
  turmaNome!: string;

  @ApiProperty({ enum: AulaAlunoTipo })
  tipo!: AulaAlunoTipo;

  @ApiProperty({ enum: PresencaStatus, nullable: true, description: 'Nulo = ainda não marcado' })
  presenca!: PresencaStatus | null;

  @ApiProperty()
  createdAt!: Date;
}

export class PaginatedFrequenciaAlunoResponseDto {
  @ApiProperty({ type: [FrequenciaAlunoResponseDto] })
  items!: FrequenciaAlunoResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  pageSize!: number;
}
