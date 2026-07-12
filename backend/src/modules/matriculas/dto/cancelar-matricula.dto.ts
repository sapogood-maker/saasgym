import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MotivoCancelamento } from '@prisma/client';
import { IsEnum, IsString, MinLength, ValidateIf } from 'class-validator';

/// Categoria sempre obrigatória (relatório de churn agrupável — ver
/// docs/16, item 10). `motivoCancelamentoDetalhe` só é exigido quando a
/// categoria é `OUTRO`: nos demais casos a categoria já basta.
export class CancelarMatriculaDto {
  @ApiProperty({ enum: MotivoCancelamento })
  @IsEnum(MotivoCancelamento)
  motivoCancelamento!: MotivoCancelamento;

  @ApiPropertyOptional({ description: 'Obrigatório quando motivoCancelamento = OUTRO' })
  @ValidateIf((dto: CancelarMatriculaDto) => dto.motivoCancelamento === MotivoCancelamento.OUTRO)
  @IsString()
  @MinLength(3)
  motivoCancelamentoDetalhe?: string;
}
