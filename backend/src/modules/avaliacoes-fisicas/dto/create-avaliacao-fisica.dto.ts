import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsNumber, IsOptional, IsPositive, IsString } from 'class-validator';

export class CreateAvaliacaoFisicaDto {
  @ApiProperty({ description: 'ISO 8601' })
  @IsDateString()
  data!: string;

  @ApiProperty({ description: 'kg' })
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  peso!: number;

  @ApiProperty({ description: 'cm' })
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  altura!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacoes?: string;
}
