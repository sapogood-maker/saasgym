import { ApiPropertyOptional, ApiProperty } from '@nestjs/swagger';
import { IsHexColor, IsOptional, IsString, MinLength } from 'class-validator';

export class CreateModalidadeDto {
  @ApiProperty()
  @IsString()
  @MinLength(2)
  nome!: string;

  @ApiPropertyOptional({ description: 'Cor hex — ex.: "#3B82F6", exibida na grade' })
  @IsOptional()
  @IsHexColor()
  cor?: string;
}
