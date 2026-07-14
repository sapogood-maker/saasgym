import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { FormaPagamento, LancamentoOrigem, LancamentoTipo } from '@prisma/client';

export class LancamentoResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty({ enum: LancamentoTipo })
  tipo!: LancamentoTipo;

  @ApiProperty({
    enum: LancamentoOrigem,
    description:
      'MANUAL (editável/removível) ou MENSALIDADE (gerado pelo sistema, somente leitura)',
  })
  origem!: LancamentoOrigem;

  @ApiProperty()
  descricao!: string;

  @ApiProperty({ nullable: true })
  categoria!: string | null;

  @ApiProperty({ description: 'Sempre número — Decimal convertido no service' })
  valor!: number;

  @ApiProperty()
  data!: Date;

  @ApiProperty({ enum: FormaPagamento, nullable: true })
  formaPagamento!: FormaPagamento | null;

  @ApiPropertyOptional({
    nullable: true,
    description: 'Preenchido quando origem = MENSALIDADE',
  })
  mensalidadeId!: string | null;

  @ApiPropertyOptional({
    nullable: true,
    description: 'Nome do aluno — só quando origem = MENSALIDADE, pra navegar até a cobrança',
  })
  alunoNome!: string | null;

  @ApiPropertyOptional({
    nullable: true,
    description:
      'Vencimento da Mensalidade de origem — só quando origem = MENSALIDADE, pra navegar até a competência correspondente em Mensalidades',
  })
  mensalidadeDataVencimento!: Date | null;

  @ApiProperty()
  createdAt!: Date;
}

export class PaginatedLancamentosResponseDto {
  @ApiProperty({ type: [LancamentoResponseDto] })
  items!: LancamentoResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  pageSize!: number;
}
