import { ApiProperty } from '@nestjs/swagger';

export class FeriadoResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  nome!: string;

  @ApiProperty()
  data!: Date;

  @ApiProperty()
  createdAt!: Date;
}

export class PaginatedFeriadosResponseDto {
  @ApiProperty({ type: [FeriadoResponseDto] })
  items!: FeriadoResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  pageSize!: number;
}
