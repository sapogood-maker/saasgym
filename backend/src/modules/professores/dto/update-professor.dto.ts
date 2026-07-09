import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';
import { IsCPF, NormalizeCPF } from '../../../common/validators/is-cpf.decorator';

export class UpdateProfessorDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(2)
  nome?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @NormalizeCPF()
  @IsCPF()
  cpf?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(8)
  telefone?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  especialidade?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacoes?: string;
}
