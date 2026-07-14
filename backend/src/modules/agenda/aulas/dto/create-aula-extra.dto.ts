import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsInt, IsOptional, IsUUID, Matches, Min } from 'class-validator';

/// Aula extra — sempre independente, `recorrenciaId = null` (docs/18,
/// seção 5, "Calendário — invariante 4"). Nunca cria nem altera
/// `Recorrencia`.
export class CreateAulaExtraDto {
  @ApiProperty()
  @IsUUID()
  turmaId!: string;

  @ApiProperty()
  @IsDateString()
  data!: string;

  @ApiProperty({ description: 'Formato HH:mm', example: '19:00' })
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'horaInicio deve estar no formato HH:mm' })
  horaInicio!: string;

  @ApiProperty()
  @IsInt()
  @Min(1)
  duracaoMinutos!: number;

  @ApiPropertyOptional({ description: 'Nulo/omitido = usa o professor titular da turma' })
  @IsOptional()
  @IsUUID()
  professorId?: string;

  @ApiPropertyOptional({ description: 'Nulo/omitido = usa a capacidade da turma' })
  @IsOptional()
  @IsInt()
  @Min(1)
  capacidadeMaxima?: number;
}
