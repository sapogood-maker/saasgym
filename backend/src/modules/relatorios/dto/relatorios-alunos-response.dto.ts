import { ApiProperty } from '@nestjs/swagger';
import { MotivoCancelamento } from '@prisma/client';

export class CancelamentoPorMotivoDto {
  @ApiProperty({ enum: MotivoCancelamento, nullable: true })
  motivo!: MotivoCancelamento | null;

  @ApiProperty()
  quantidade!: number;
}

export class AlunosMensalItemDto {
  @ApiProperty()
  mes!: number;

  @ApiProperty()
  ano!: number;

  @ApiProperty({ description: 'Matrículas iniciadas no mês, exceto renovação' })
  novosAlunos!: number;

  @ApiProperty({ description: 'Matrículas canceladas no mês (status = CANCELADA)' })
  cancelamentos!: number;

  @ApiProperty({ type: [CancelamentoPorMotivoDto] })
  cancelamentosPorMotivo!: CancelamentoPorMotivoDto[];

  @ApiProperty({ description: 'novosAlunos - cancelamentos' })
  saldoLiquido!: number;
}

/// Ordenado do mês âncora (mais recente) pro mais antigo — mesmo sentido de
/// `DashboardEvolucaoResponseDto`. Sem curva de "alunos ativos"/"taxa de
/// retenção" por mês: sem histórico de status guardado (Matricula não
/// registra transições ao longo do tempo), não dá pra reconstruir esse
/// número com exatidão pra meses passados — decisão explícita do dono do
/// produto (2026-07-16) foi não fingir precisão que o dado não tem. Ver
/// `RelatoriosService.resumo` pro snapshot atual (não histórico) desses
/// dois indicadores.
export class RelatoriosAlunosResponseDto {
  @ApiProperty({ type: [AlunosMensalItemDto] })
  meses!: AlunosMensalItemDto[];
}
