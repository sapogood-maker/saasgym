import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { FormaPagamento, LancamentoTipo } from '@prisma/client';
import {
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  MinLength,
} from 'class-validator';

/// Sem mensalidadeId — lançamento manual é sempre desvinculado de
/// Mensalidade (a ligação só existe pro lançamento que o próprio sistema
/// cria em MensalidadesService.marcarPaga, docs/17 item 4).
export class CreateLancamentoDto {
  @ApiProperty({ enum: LancamentoTipo })
  @IsEnum(LancamentoTipo)
  tipo!: LancamentoTipo;

  @ApiProperty()
  @IsString()
  @MinLength(2)
  descricao!: string;

  @ApiPropertyOptional({ description: 'Texto livre — sem catálogo nesta fase (docs/17, item 8)' })
  @IsOptional()
  @IsString()
  categoria?: string;

  @ApiProperty()
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  valor!: number;

  @ApiProperty({ description: 'ISO 8601' })
  @IsDateString()
  data!: string;

  @ApiPropertyOptional({ enum: FormaPagamento })
  @IsOptional()
  @IsEnum(FormaPagamento)
  formaPagamento?: FormaPagamento;
}
