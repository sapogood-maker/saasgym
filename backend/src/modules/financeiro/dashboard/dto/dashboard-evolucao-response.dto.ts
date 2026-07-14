import { ApiProperty } from '@nestjs/swagger';

export class EvolucaoMensalItemDto {
  @ApiProperty()
  mes!: number;

  @ApiProperty()
  ano!: number;

  @ApiProperty()
  receitaPrevista!: number;

  @ApiProperty()
  receitaRecebida!: number;

  @ApiProperty()
  despesas!: number;

  @ApiProperty()
  saldo!: number;
}

/// Ordenado do mês âncora (mais recente) pro mais antigo — mesmo sentido
/// "mais recente primeiro" já usado nas listagens do projeto.
export class DashboardEvolucaoResponseDto {
  @ApiProperty({ type: [EvolucaoMensalItemDto] })
  meses!: EvolucaoMensalItemDto[];
}
