import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';
import { IsCPF } from '../../../common/validators/is-cpf.decorator';

export class CreateProfessorDto {
  @ApiProperty()
  @IsString()
  @MinLength(2)
  nome!: string;

  @ApiProperty({ example: '111.444.777-35' })
  @IsCPF()
  cpf!: string;

  @ApiProperty()
  @IsString()
  @MinLength(8)
  telefone!: string;

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
