import { ApiProperty } from '@nestjs/swagger';

/// Resumo financeiro do período (Caixa) — soma real no banco, não
/// client-side (client só vê a página atual da lista paginada). Base do
/// "resumo financeiro no topo" do MS4 (docs/17).
export class ResumoLancamentosResponseDto {
  @ApiProperty()
  totalReceitas!: number;

  @ApiProperty()
  totalDespesas!: number;

  @ApiProperty({ description: 'totalReceitas - totalDespesas' })
  saldo!: number;

  @ApiProperty()
  quantidadeReceitas!: number;

  @ApiProperty()
  quantidadeDespesas!: number;
}
