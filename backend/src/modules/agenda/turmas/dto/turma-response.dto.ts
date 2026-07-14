import { ApiProperty } from '@nestjs/swagger';
import { UserStatus } from '@prisma/client';

export class TurmaResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  nome!: string;

  @ApiProperty()
  modalidadeId!: string;

  @ApiProperty()
  modalidadeNome!: string;

  @ApiProperty()
  professorId!: string;

  @ApiProperty()
  professorNome!: string;

  @ApiProperty({ nullable: true, description: 'Nulo = ilimitado' })
  capacidadeMaxima!: number | null;

  @ApiProperty({ nullable: true })
  local!: string | null;

  @ApiProperty({ enum: UserStatus })
  status!: UserStatus;

  @ApiProperty()
  createdAt!: Date;
}

export class PaginatedTurmasResponseDto {
  @ApiProperty({ type: [TurmaResponseDto] })
  items!: TurmaResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  pageSize!: number;
}
