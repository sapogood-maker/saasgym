import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

/// `mes`/`ano` são a âncora da janela (o mês mais recente da série,
/// default: mês corrente) — não um filtro isolado. `meses` é o tamanho
/// da janela olhando pra trás a partir da âncora.
export class DashboardEvolucaoQueryDto {
  @ApiPropertyOptional({ description: 'Mês âncora (1-12) — default: mês corrente' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(12)
  mes?: number;

  @ApiPropertyOptional({ description: 'Ano âncora — default: ano corrente' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  ano?: number;

  @ApiPropertyOptional({ description: 'Quantidade de meses na janela — default: 6', default: 6 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(24)
  meses?: number;
}
