import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Sexo } from '@prisma/client';
import { IsDateString, IsEmail, IsEnum, IsOptional, IsString, MinLength } from 'class-validator';
import { IsCPF, NormalizeCPF } from '../../../common/validators/is-cpf.decorator';

export class CreateAlunoDto {
  @ApiProperty()
  @IsString()
  @MinLength(2)
  nome!: string;

  @ApiProperty({ example: '111.444.777-35' })
  @NormalizeCPF()
  @IsCPF()
  cpf!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  rg?: string;

  @ApiProperty({ example: '2000-01-31' })
  @IsDateString()
  dataNascimento!: string;

  @ApiProperty({ enum: Sexo })
  @IsEnum(Sexo)
  sexo!: Sexo;

  @ApiProperty()
  @IsString()
  @MinLength(8)
  telefone!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  whatsapp?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  endereco?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  cidade?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  estado?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  cep?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacoes?: string;
}
