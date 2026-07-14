import { ApiProperty } from '@nestjs/swagger';
import { UserStatus } from '@prisma/client';

export class ModalidadeResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  nome!: string;

  @ApiProperty({ nullable: true })
  cor!: string | null;

  @ApiProperty({ enum: UserStatus })
  status!: UserStatus;

  @ApiProperty()
  createdAt!: Date;
}

export class PaginatedModalidadesResponseDto {
  @ApiProperty({ type: [ModalidadeResponseDto] })
  items!: ModalidadeResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  pageSize!: number;
}
