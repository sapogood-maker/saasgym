import { ApiProperty } from '@nestjs/swagger';

/// Item da lista de alertas do Dashboard (Centro de Operações, docs/22) —
/// mensalidades PENDENTE já vencidas ou a vencer numa janela curta,
/// combinadas numa única lista acionável (aluno + valor + vencimento),
/// não só um número.
export class MensalidadeAlertaResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  alunoId!: string;

  @ApiProperty()
  alunoNome!: string;

  @ApiProperty()
  valor!: number;

  @ApiProperty()
  dataVencimento!: Date;

  @ApiProperty({ description: 'true = já vencida; false = vence dentro da janela consultada' })
  vencida!: boolean;
}
