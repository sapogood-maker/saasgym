import { ApiProperty } from '@nestjs/swagger';
import { AcademiaStatus } from '@prisma/client';

export class AcademiaResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  nome!: string;

  @ApiProperty({ nullable: true })
  cnpj!: string | null;

  @ApiProperty({ nullable: true })
  email!: string | null;

  @ApiProperty({ nullable: true })
  telefone!: string | null;

  @ApiProperty({ nullable: true })
  endereco!: string | null;

  @ApiProperty({ nullable: true })
  dominio!: string | null;

  @ApiProperty({ enum: AcademiaStatus })
  status!: AcademiaStatus;

  @ApiProperty({ nullable: true })
  trialExpiresAt!: Date | null;

  @ApiProperty()
  planoSaasId!: string;

  @ApiProperty()
  createdAt!: Date;
}

export class PaginatedAcademiasResponseDto {
  @ApiProperty({ type: [AcademiaResponseDto] })
  items!: AcademiaResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  pageSize!: number;
}
