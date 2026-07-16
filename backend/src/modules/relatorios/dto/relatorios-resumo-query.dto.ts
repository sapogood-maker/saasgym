import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

/// Janela (em meses, terminando no mês corrente) usada só pra aproximar a
/// taxa de retenção — ver comentário em `RelatoriosService.resumo`.
export class RelatoriosResumoQueryDto {
  @ApiPropertyOptional({ description: 'Tamanho da janela em meses — default: 6', default: 6 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(24)
  meses?: number;
}
