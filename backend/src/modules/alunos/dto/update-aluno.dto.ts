import { ApiPropertyOptional } from '@nestjs/swagger';
import { Sexo } from '@prisma/client';
import { IsDateString, IsEmail, IsEnum, IsOptional, IsString, MinLength } from 'class-validator';
import { IsCPF } from '../../../common/validators/is-cpf.decorator';

export class UpdateAlunoDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(2)
  nome?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsCPF()
  cpf?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  rg?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  dataNascimento?: string;

  @ApiPropertyOptional({ enum: Sexo })
  @IsOptional()
  @IsEnum(Sexo)
  sexo?: Sexo;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(8)
  telefone?: string;

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
