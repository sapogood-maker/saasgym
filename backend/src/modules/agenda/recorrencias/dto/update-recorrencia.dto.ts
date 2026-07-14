import { ApiPropertyOptional } from '@nestjs/swagger';
import { RecorrenciaTipo } from '@prisma/client';
import {
  IsBoolean,
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

/// Todos os campos opcionais (PATCH parcial). Se `tipo` for enviado, o
/// campo correspondente (`diaSemana`/`diaDoMes`/`intervaloDias`) é exigido
/// pelo mesmo `@ValidateIf` do create; se `tipo` não for enviado, a
/// consistência do tipo já persistido com os campos que estão mudando é
/// conferida no service (mesmo padrão condicional documentado em docs/18,
/// seção 2 item 3). `ativo` permite pausar uma recorrência sem apagar
/// histórico (campo já existe desde o MS1).
export class UpdateRecorrenciaDto {
  @ApiPropertyOptional({ enum: RecorrenciaTipo })
  @IsOptional()
  @IsEnum(RecorrenciaTipo)
  tipo?: RecorrenciaTipo;

  @ApiPropertyOptional({ description: 'Obrigatório quando tipo = SEMANAL (0 = domingo … 6 = sábado)' })
  @ValidateIf((dto: UpdateRecorrenciaDto) => dto.tipo === RecorrenciaTipo.SEMANAL)
  @IsInt()
  @Min(0)
  @Max(6)
  diaSemana?: number;

  @ApiPropertyOptional({ description: 'Obrigatório quando tipo = MENSAL (dia fixo do mês, 1-31)' })
  @ValidateIf((dto: UpdateRecorrenciaDto) => dto.tipo === RecorrenciaTipo.MENSAL)
  @IsInt()
  @Min(1)
  @Max(31)
  diaDoMes?: number;

  @ApiPropertyOptional({ description: 'Obrigatório quando tipo = INTERVALADA (ex.: 14 = quinzenal)' })
  @ValidateIf((dto: UpdateRecorrenciaDto) => dto.tipo === RecorrenciaTipo.INTERVALADA)
  @IsInt()
  @Min(1)
  intervaloDias?: number;

  @ApiPropertyOptional({ description: 'Formato HH:mm', example: '07:00' })
  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'horaInicio deve estar no formato HH:mm' })
  horaInicio?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1)
  duracaoMinutos?: number;

  @ApiPropertyOptional({ description: 'Override pontual do professor titular da Turma só para esta recorrência' })
  @IsOptional()
  @IsUUID()
  professorId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  dataInicioVigencia?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  dataFimVigencia?: string;

  @ApiPropertyOptional({ description: 'Desativa sem apagar histórico' })
  @IsOptional()
  @IsBoolean()
  ativo?: boolean;
}
