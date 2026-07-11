import { ApiProperty } from '@nestjs/swagger';
import { Periodicidade, UserStatus } from '@prisma/client';

export class PlanoResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  nome!: string;

  @ApiProperty({ nullable: true })
  descricao!: string | null;

  @ApiProperty({ enum: Periodicidade })
  periodicidade!: Periodicidade;

  @ApiProperty({ description: 'Sempre número — Decimal convertido no service' })
  valor!: number;

  @ApiProperty({ nullable: true, description: 'Nulo = ilimitado' })
  quantidadeAulas!: number | null;

  @ApiProperty({ nullable: true })
  ordem!: number | null;

  @ApiProperty({ enum: UserStatus })
  status!: UserStatus;

  @ApiProperty()
  createdAt!: Date;
}

export class PaginatedPlanosResponseDto {
  @ApiProperty({ type: [PlanoResponseDto] })
  items!: PlanoResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  pageSize!: number;
}
