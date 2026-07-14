import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsNumber, IsOptional, Min } from 'class-validator';

/// Só o que ainda faz sentido corrigir antes do pagamento — sem
/// alunoId/matriculaId/valor (valor é o snapshot de Matricula.valor na
/// geração, não um campo de "preço de tabela" pra editar; desconto/multa
/// são os ajustes por cobrança). Bloqueado fora de status PENDENTE (ver
/// MensalidadesService.update).
export class UpdateMensalidadeDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  desconto?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  multa?: number;

  @ApiPropertyOptional({ description: 'ISO 8601' })
  @IsOptional()
  @IsDateString()
  dataVencimento?: string;
}
