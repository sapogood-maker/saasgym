import { ApiPropertyOptional } from '@nestjs/swagger';
import { FormaPagamento, LancamentoTipo } from '@prisma/client';
import {
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  MinLength,
} from 'class-validator';

export class UpdateLancamentoDto {
  @ApiPropertyOptional({ enum: LancamentoTipo })
  @IsOptional()
  @IsEnum(LancamentoTipo)
  tipo?: LancamentoTipo;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(2)
  descricao?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  categoria?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  valor?: number;

  @ApiPropertyOptional({ description: 'ISO 8601' })
  @IsOptional()
  @IsDateString()
  data?: string;

  @ApiPropertyOptional({ enum: FormaPagamento })
  @IsOptional()
  @IsEnum(FormaPagamento)
  formaPagamento?: FormaPagamento;
}
