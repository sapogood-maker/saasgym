import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

/// Default = mês/ano corrente — cobre o caso mais comum ("gerar as
/// mensalidades deste mês") sem exigir que o usuário informe nada.
export class GerarMensalidadesDto {
  @ApiPropertyOptional({ description: 'Mês (1-12). Default: mês corrente' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(12)
  mes?: number;

  @ApiPropertyOptional({ description: 'Ano. Default: ano corrente' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(2000)
  ano?: number;
}
