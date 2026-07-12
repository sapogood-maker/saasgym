import { ApiProperty } from '@nestjs/swagger';
import { MatriculaStatus, MotivoCancelamento } from '@prisma/client';

export class MatriculaResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  alunoId!: string;

  @ApiProperty()
  planoId!: string;

  @ApiProperty()
  createdByUserId!: string;

  @ApiProperty({ description: 'Sempre número — Decimal convertido no service' })
  valor!: number;

  @ApiProperty()
  diaVencimento!: number;

  @ApiProperty()
  dataInicio!: Date;

  @ApiProperty({ description: 'Calculada uma vez na criação, nunca muda' })
  dataFimPrevista!: Date;

  @ApiProperty({ description: 'Vigente — estendida por trancamento' })
  dataFim!: Date;

  @ApiProperty({ enum: MatriculaStatus })
  status!: MatriculaStatus;

  @ApiProperty({ nullable: true })
  trancadoEm!: Date | null;

  @ApiProperty({ nullable: true })
  trancamentoMotivo!: string | null;

  @ApiProperty({ enum: MotivoCancelamento, nullable: true })
  motivoCancelamento!: MotivoCancelamento | null;

  @ApiProperty({ nullable: true })
  motivoCancelamentoDetalhe!: string | null;

  @ApiProperty({
    nullable: true,
    description: 'Preenchido quando esta matrícula nasceu de uma renovação',
  })
  matriculaAnteriorId!: string | null;

  @ApiProperty()
  createdAt!: Date;
}

export class PaginatedMatriculasResponseDto {
  @ApiProperty({ type: [MatriculaResponseDto] })
  items!: MatriculaResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  pageSize!: number;
}
