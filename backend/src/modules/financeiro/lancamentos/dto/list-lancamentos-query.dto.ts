import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { LancamentoTipo } from '@prisma/client';
import { IsDateString, IsEnum, IsInt, IsOptional, Max, Min } from 'class-validator';
import { PaginationQueryDto } from '../../../../common/dto/pagination-query.dto';

export class ListLancamentosQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: LancamentoTipo })
  @IsOptional()
  @IsEnum(LancamentoTipo)
  tipo?: LancamentoTipo;

  @ApiPropertyOptional({
    description: 'Competência (1-12) — mesmo eixo de Mensalidades. Se informado com `ano`, ' +
      'tem prioridade sobre `dataInicio`/`dataFim`.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(12)
  mes?: number;

  @ApiPropertyOptional({ description: 'Ano da competência' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  ano?: number;

  @ApiPropertyOptional({ description: 'ISO 8601 — início do intervalo (inclusive)' })
  @IsOptional()
  @IsDateString()
  dataInicio?: string;

  @ApiPropertyOptional({ description: 'ISO 8601 — fim do intervalo (inclusive)' })
  @IsOptional()
  @IsDateString()
  dataFim?: string;
}
