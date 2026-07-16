import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

/// `mes`/`ano` são a âncora da janela (mês mais recente da série, default:
/// mês corrente); `meses` é o tamanho da janela olhando pra trás — mesmo
/// contrato de `DashboardEvolucaoQueryDto` (Financeiro), duplicado aqui de
/// propósito pra não acoplar o módulo de Relatórios a um DTO interno de
/// outro módulo (mesmo padrão já usado entre Mensalidades/Lançamentos).
export class RelatoriosEvolucaoQueryDto {
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
