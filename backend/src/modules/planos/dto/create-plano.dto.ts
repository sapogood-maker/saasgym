import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
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

export class CreatePlanoDto {
  @ApiProperty()
  @IsString()
  @MinLength(2)
  nome!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  descricao?: string;

  @ApiProperty({ enum: Periodicidade })
  @IsEnum(Periodicidade)
  periodicidade!: Periodicidade;

  @ApiProperty({ example: 149.9, description: 'Valor da mensalidade, até 2 casas decimais' })
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  valor!: number;

  @ApiPropertyOptional({ description: 'Nulo = ilimitado' })
  @IsOptional()
  @IsInt()
  @Min(1)
  quantidadeAulas?: number;

  @ApiPropertyOptional({ description: 'Ordem de exibição — menor primeiro' })
  @IsOptional()
  @IsInt()
  @Min(0)
  ordem?: number;
}
