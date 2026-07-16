import { ApiProperty } from '@nestjs/swagger';

/// Snapshot atual (não uma série histórica) — ver comentário em
/// `RelatoriosService.resumo` sobre a aproximação de `taxaRetencaoAproximada`.
export class RelatoriosResumoResponseDto {
  @ApiProperty({ description: 'Janela (em meses) usada pra aproximar a retenção' })
  meses!: number;

  @ApiProperty()
  alunosAtivosHoje!: number;

  @ApiProperty({ description: 'Matrículas canceladas dentro da janela' })
  cancelamentosPeriodo!: number;

  @ApiProperty({
    description:
      'Aproximação: 1 - cancelamentosPeriodo / (alunosAtivosHoje + cancelamentosPeriodo)',
  })
  taxaRetencaoAproximada!: number;
}
