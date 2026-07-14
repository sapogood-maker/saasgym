import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, IsUUID, Min, MinLength } from 'class-validator';

export class UpdateTurmaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(2)
  nome?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  modalidadeId?: string;

  @ApiPropertyOptional({ description: 'Professor titular padrão' })
  @IsOptional()
  @IsUUID()
  professorId?: string;

  @ApiPropertyOptional({ description: 'Nulo = ilimitado' })
  @IsOptional()
  @IsInt()
  @Min(1)
  capacidadeMaxima?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  local?: string;
}
