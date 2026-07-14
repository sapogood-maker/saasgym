import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { RecorrenciaTipo } from '@prisma/client';
import {
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsUUID,
  Matches,
  Max,
  Min,
  ValidateIf,
} from 'class-validator';

/// `turmaId` não é campo do DTO — vem da rota
/// (`agenda/turmas/:turmaId/recorrencias`), reforçando a invariante
/// "Recorrência pertence exclusivamente à Turma" (docs/18, seção 2 item 3).
/// Só o campo relevante ao `tipo` é exigido (`diaSemana`/`diaDoMes`/
/// `intervaloDias`) — os outros dois ficam vazios.
export class CreateRecorrenciaDto {
  @ApiProperty({ enum: RecorrenciaTipo })
  @IsEnum(RecorrenciaTipo)
  tipo!: RecorrenciaTipo;

  @ApiPropertyOptional({ description: 'Obrigatório quando tipo = SEMANAL (0 = domingo … 6 = sábado)' })
  @ValidateIf((dto: CreateRecorrenciaDto) => dto.tipo === RecorrenciaTipo.SEMANAL)
  @IsInt()
  @Min(0)
  @Max(6)
  diaSemana?: number;

  @ApiPropertyOptional({ description: 'Obrigatório quando tipo = MENSAL (dia fixo do mês, 1-31)' })
  @ValidateIf((dto: CreateRecorrenciaDto) => dto.tipo === RecorrenciaTipo.MENSAL)
  @IsInt()
  @Min(1)
  @Max(31)
  diaDoMes?: number;

  @ApiPropertyOptional({ description: 'Obrigatório quando tipo = INTERVALADA (ex.: 14 = quinzenal)' })
  @ValidateIf((dto: CreateRecorrenciaDto) => dto.tipo === RecorrenciaTipo.INTERVALADA)
  @IsInt()
  @Min(1)
  intervaloDias?: number;

  @ApiProperty({ description: 'Formato HH:mm', example: '07:00' })
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'horaInicio deve estar no formato HH:mm' })
  horaInicio!: string;

  @ApiProperty()
  @IsInt()
  @Min(1)
  duracaoMinutos!: number;

  @ApiPropertyOptional({ description: 'Override pontual do professor titular da Turma só para esta recorrência' })
  @IsOptional()
  @IsUUID()
  professorId?: string;

  @ApiProperty()
  @IsDateString()
  dataInicioVigencia!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  dataFimVigencia?: string;
}
