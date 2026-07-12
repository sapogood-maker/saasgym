import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  IsPositive,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class CreateMatriculaDto {
  @ApiProperty()
  @IsUUID()
  alunoId!: string;

  @ApiProperty()
  @IsUUID()
  planoId!: string;

  @ApiProperty({ description: 'Data de início da vigência (ISO 8601)' })
  @IsDateString()
  dataInicio!: string;

  @ApiPropertyOptional({
    description: 'Dia do mês de vencimento (1-31). Default: dia de dataInicio',
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(31)
  diaVencimento?: number;

  @ApiPropertyOptional({
    description: 'Valor mensal acordado (permite desconto negociado). Default: Plano.valor',
  })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  valor?: number;
}
