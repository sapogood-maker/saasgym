import { ApiProperty } from '@nestjs/swagger';

export class AvaliacaoFisicaResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  alunoId!: string;

  @ApiProperty()
  data!: Date;

  @ApiProperty({ description: 'kg' })
  peso!: number;

  @ApiProperty({ description: 'cm' })
  altura!: number;

  @ApiProperty({ description: 'peso / (altura/100)² — calculado, nunca armazenado' })
  imc!: number;

  @ApiProperty({ nullable: true })
  observacoes!: string | null;

  @ApiProperty()
  createdAt!: Date;
}

export class PaginatedAvaliacoesFisicasResponseDto {
  @ApiProperty({ type: [AvaliacaoFisicaResponseDto] })
  items!: AvaliacaoFisicaResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  pageSize!: number;
}
