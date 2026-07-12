import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsInt, IsNumber, IsOptional, IsPositive, Max, Min } from 'class-validator';

export class RenovarMatriculaDto {
  @ApiPropertyOptional({ description: 'Default: dia seguinte ao dataFim da matrícula atual' })
  @IsOptional()
  @IsDateString()
  dataInicio?: string;

  @ApiPropertyOptional({ description: 'Default: mesmo diaVencimento da matrícula atual' })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(31)
  diaVencimento?: number;

  @ApiPropertyOptional({ description: 'Default: mesmo valor da matrícula atual' })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  valor?: number;
}
