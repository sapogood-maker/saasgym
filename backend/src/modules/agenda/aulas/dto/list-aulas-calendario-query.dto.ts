import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { AulaStatus } from '@prisma/client';
import { IsDateString, IsEnum, IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';

/// Endpoint de calendário — já nasce aceitando os 4 filtros combinados
/// (docs/18, seção 7, decisão confirmada), mesmo que a UI do MS7 exponha
/// só parte deles de início.
export class ListAulasCalendarioQueryDto {
  @ApiPropertyOptional({ description: 'Filtra aulas com data >= dataInicio' })
  @IsOptional()
  @IsDateString()
  dataInicio?: string;

  @ApiPropertyOptional({ description: 'Filtra aulas com data <= dataFim' })
  @IsOptional()
  @IsDateString()
  dataFim?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  turmaId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  professorId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  modalidadeId?: string;

  @ApiPropertyOptional({ enum: AulaStatus })
  @IsOptional()
  @IsEnum(AulaStatus)
  status?: AulaStatus;

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
  @Max(200)
  pageSize: number = 20;
}
