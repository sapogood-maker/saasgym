import { ApiProperty } from '@nestjs/swagger';
import { UserStatus } from '@prisma/client';

export class ProfessorResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty({ nullable: true })
  fotoUrl!: string | null;

  @ApiProperty()
  nome!: string;

  @ApiProperty()
  cpf!: string;

  @ApiProperty()
  telefone!: string;

  @ApiProperty({ nullable: true })
  email!: string | null;

  @ApiProperty({ nullable: true })
  especialidade!: string | null;

  @ApiProperty({ nullable: true })
  observacoes!: string | null;

  @ApiProperty({ enum: UserStatus })
  status!: UserStatus;

  @ApiProperty()
  createdAt!: Date;
}

export class PaginatedProfessoresResponseDto {
  @ApiProperty({ type: [ProfessorResponseDto] })
  items!: ProfessorResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  pageSize!: number;
}
