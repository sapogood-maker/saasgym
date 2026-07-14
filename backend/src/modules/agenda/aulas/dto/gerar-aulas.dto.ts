import { ApiProperty } from '@nestjs/swagger';
import { IsDateString } from 'class-validator';

export class GerarAulasDto {
  @ApiProperty({ description: 'Início do período a gerar (inclusive)' })
  @IsDateString()
  dataInicio!: string;

  @ApiProperty({ description: 'Fim do período a gerar (inclusive)' })
  @IsDateString()
  dataFim!: string;
}
