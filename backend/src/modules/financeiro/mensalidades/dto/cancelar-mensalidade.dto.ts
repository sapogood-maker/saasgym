import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

/// Motivo em texto livre, opcional — sem categorização (docs/17-modulo-3-
/// financeiro-analise.md, item 7): ainda não há um 2º caso de uso real
/// pedindo relatório agrupado sobre cancelamento de Mensalidade
/// isoladamente (diferente de MotivoCancelamento de Matrícula, que já
/// nasceu com essa necessidade clara de relatório de churn).
export class CancelarMensalidadeDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  motivo?: string;
}
