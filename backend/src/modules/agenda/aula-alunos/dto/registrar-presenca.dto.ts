import { ApiProperty } from '@nestjs/swagger';
import { PresencaStatus } from '@prisma/client';
import { IsEnum } from 'class-validator';

/// Registrar e alterar presença são a mesma operação (docs/18, seção 5,
/// "Frequência — invariante 4"): não há histórico de mudanças de
/// presença, só o valor atual de `AulaAluno.presenca`.
export class RegistrarPresencaDto {
  @ApiProperty({ enum: PresencaStatus })
  @IsEnum(PresencaStatus)
  presenca!: PresencaStatus;
}
