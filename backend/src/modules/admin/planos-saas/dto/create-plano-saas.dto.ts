import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsObject, IsOptional, IsString, Min, MinLength } from 'class-validator';

export class CreatePlanoSaasDto {
  @ApiProperty()
  @IsString()
  @MinLength(2)
  nome!: string;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  ativo?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  ordem?: number;

  @ApiPropertyOptional({ description: 'null = ilimitado' })
  @IsOptional()
  @IsInt()
  @Min(0)
  limiteAlunos?: number;

  @ApiPropertyOptional({ description: 'null = ilimitado' })
  @IsOptional()
  @IsInt()
  @Min(0)
  limiteProfessores?: number;

  @ApiPropertyOptional({ description: 'null = ilimitado' })
  @IsOptional()
  @IsInt()
  @Min(0)
  limiteUsuarios?: number;

  @ApiPropertyOptional({ description: 'null = ilimitado' })
  @IsOptional()
  @IsInt()
  @Min(0)
  limiteArmazenamentoMb?: number;

  @ApiPropertyOptional({ description: 'null = ilimitado' })
  @IsOptional()
  @IsInt()
  @Min(0)
  limiteBackups?: number;

  @ApiPropertyOptional({ description: 'Feature flags livres' })
  @IsOptional()
  @IsObject()
  funcionalidades?: Record<string, unknown>;
}
