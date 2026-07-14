import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsHexColor, IsOptional, IsString, MinLength } from 'class-validator';

export class UpdateModalidadeDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(2)
  nome?: string;

  @ApiPropertyOptional({ description: 'Cor hex — ex.: "#3B82F6"' })
  @IsOptional()
  @IsHexColor()
  cor?: string;
}
