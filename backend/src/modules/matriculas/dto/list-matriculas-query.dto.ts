import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { MatriculaStatus } from '@prisma/client';
import { IsEnum, IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';

export class ListMatriculasQueryDto {
  @ApiPropertyOptional({ description: 'Filtra por aluno' })
  @IsOptional()
  @IsUUID()
  alunoId?: string;

  @ApiPropertyOptional({ description: 'Filtra por plano' })
  @IsOptional()
  @IsUUID()
  planoId?: string;

  @ApiPropertyOptional({ enum: MatriculaStatus })
  @IsOptional()
  @IsEnum(MatriculaStatus)
  status?: MatriculaStatus;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page: number = 1;

  @ApiPropertyOptional({ default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize: number = 20;
}
