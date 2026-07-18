import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import { AulaStatus } from '@prisma/client';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

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

  /// Sprint "Agenda operacional" (docs/33) — pedido explicitamente opt-in:
  /// a Agenda em modo Dia/Semana passa `true` pra trazer os nomes na MESMA
  /// consulta paginada (sem round-trip extra); a visão Mês nunca passa,
  /// mantendo a consulta idêntica à de antes dessa sprint (sem custo a
  /// mais numa janela de até 6 semanas).
  @ApiPropertyOptional({
    default: false,
    description: 'Inclui os nomes dos alunos de cada aula na mesma consulta (Dia/Semana da Agenda)',
  })
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  incluirAlunos: boolean = false;

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
