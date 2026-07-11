import { ApiPropertyOptional } from '@nestjs/swagger';
import { Periodicidade } from '@prisma/client';
import {
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Min,
  MinLength,
} from 'class-validator';

export class UpdatePlanoDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(2)
  nome?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  descricao?: string;

  @ApiPropertyOptional({ enum: Periodicidade })
  @IsOptional()
  @IsEnum(Periodicidade)
  periodicidade?: Periodicidade;

  @ApiPropertyOptional({ example: 149.9 })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  valor?: number;

  @ApiPropertyOptional({ description: 'Nulo = ilimitado' })
  @IsOptional()
  @IsInt()
  @Min(1)
  quantidadeAulas?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  ordem?: number;
}
