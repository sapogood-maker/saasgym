import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, IsUUID, Min, MinLength } from 'class-validator';

export class CreateTurmaDto {
  @ApiProperty()
  @IsString()
  @MinLength(2)
  nome!: string;

  @ApiProperty()
  @IsUUID()
  modalidadeId!: string;

  @ApiProperty({ description: 'Professor titular padrão' })
  @IsUUID()
  professorId!: string;

  @ApiPropertyOptional({ description: 'Nulo = ilimitado' })
  @IsOptional()
  @IsInt()
  @Min(1)
  capacidadeMaxima?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  local?: string;
}
