import { ApiProperty } from '@nestjs/swagger';
import { FormaPagamento, MensalidadeStatus } from '@prisma/client';

export class MensalidadeResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  matriculaId!: string;

  @ApiProperty()
  alunoId!: string;

  @ApiProperty({ description: 'Projeção de leitura — evita N+1 na listagem' })
  alunoNome!: string;

  @ApiProperty({ description: 'Sempre número — Decimal convertido no service' })
  valor!: number;

  @ApiProperty()
  desconto!: number;

  @ApiProperty()
  multa!: number;

  @ApiProperty({ description: 'valor - desconto + multa, calculado — nunca armazenado' })
  valorFinal!: number;

  @ApiProperty()
  dataVencimento!: Date;

  @ApiProperty({ nullable: true })
  dataPagamento!: Date | null;

  @ApiProperty({ enum: MensalidadeStatus })
  status!: MensalidadeStatus;

  @ApiProperty({ description: 'status = PENDENTE e dataVencimento no passado — sempre calculado' })
  atrasada!: boolean;

  @ApiProperty({ nullable: true })
  motivoCancelamento!: string | null;

  @ApiProperty({
    enum: FormaPagamento,
    nullable: true,
    description: 'Vem do Lancamento gerado ao pagar',
  })
  formaPagamento!: FormaPagamento | null;

  @ApiProperty()
  createdAt!: Date;
}

export class PaginatedMensalidadesResponseDto {
  @ApiProperty({ type: [MensalidadeResponseDto] })
  items!: MensalidadeResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  pageSize!: number;
}

export class GerarMensalidadesResponseDto {
  @ApiProperty({ type: [MensalidadeResponseDto] })
  criadas!: MensalidadeResponseDto[];

  @ApiProperty({
    description: 'Matrículas que já tinham Mensalidade gerada pro período — geração é idempotente',
  })
  totalPuladas!: number;
}
