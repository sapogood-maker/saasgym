import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

/// Sem mes/ano informados, o service usa o mês corrente — mesmo padrão de
/// `GerarMensalidadesDto`/`ResumoLancamentosQueryDto`.
export class DashboardResumoQueryDto {
  @ApiPropertyOptional({ description: 'Competência (1-12) — default: mês corrente' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(12)
  mes?: number;

  @ApiPropertyOptional({ description: 'Ano da competência — default: ano corrente' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  ano?: number;
}
