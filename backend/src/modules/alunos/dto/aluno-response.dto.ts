import { ApiProperty } from '@nestjs/swagger';
import { Sexo, UserStatus } from '@prisma/client';

export class AlunoResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty({ nullable: true })
  fotoUrl!: string | null;

  @ApiProperty()
  nome!: string;

  @ApiProperty()
  cpf!: string;

  @ApiProperty({ nullable: true })
  rg!: string | null;

  @ApiProperty()
  dataNascimento!: Date;

  @ApiProperty({ enum: Sexo })
  sexo!: Sexo;

  @ApiProperty()
  telefone!: string;

  @ApiProperty({ nullable: true })
  whatsapp!: string | null;

  @ApiProperty({ nullable: true })
  email!: string | null;

  @ApiProperty({ nullable: true })
  endereco!: string | null;

  @ApiProperty({ nullable: true })
  cidade!: string | null;

  @ApiProperty({ nullable: true })
  estado!: string | null;

  @ApiProperty({ nullable: true })
  cep!: string | null;

  @ApiProperty({ nullable: true })
  observacoes!: string | null;

  @ApiProperty({ enum: UserStatus })
  status!: UserStatus;

  @ApiProperty()
  createdAt!: Date;
}

export class PaginatedAlunosResponseDto {
  @ApiProperty({ type: [AlunoResponseDto] })
  items!: AlunoResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  pageSize!: number;
}
