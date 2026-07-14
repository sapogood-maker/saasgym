import { ApiProperty } from '@nestjs/swagger';

/// Indicadores do topo do Painel Financeiro (mês selecionado) — orquestra
/// `MensalidadesService` (receitaPrevista, inadimplencia) e
/// `LancamentosService` (resumo) numa única resposta, reduzindo chamadas
/// do frontend (docs/17, seção "MS5"). Taxa de recebimento
/// (receitaRecebida / receitaPrevista) é calculada no frontend, não aqui.
export class DashboardResumoResponseDto {
  @ApiProperty()
  mes!: number;

  @ApiProperty()
  ano!: number;

  @ApiProperty({ description: 'Soma de Matricula.valor das ATIVA cuja vigência cobre o mês' })
  receitaPrevista!: number;

  @ApiProperty({ description: 'Soma de Lancamento tipo RECEITA do mês (manual + gerado por Mensalidade)' })
  receitaRecebida!: number;

  @ApiProperty()
  despesas!: number;

  @ApiProperty({ description: 'receitaRecebida - despesas' })
  saldo!: number;

  @ApiProperty({ description: 'Sempre tempo real — todas as Mensalidade PENDENTE vencidas até hoje' })
  inadimplenciaValor!: number;

  @ApiProperty()
  inadimplenciaQuantidade!: number;
}
