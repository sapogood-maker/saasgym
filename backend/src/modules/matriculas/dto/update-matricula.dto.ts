import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsNumber, IsOptional, IsPositive, Max, Min } from 'class-validator';

/// Deliberadamente sem `planoId`/`alunoId` — imutáveis após a criação
/// (docs/16-modulo-2-matriculas-analise.md, item 12). Upgrade/renovação
/// nunca é uma edição, é sempre `POST /matriculas/:id/renovar`.
export class UpdateMatriculaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  valor?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(31)
  diaVencimento?: number;
}
