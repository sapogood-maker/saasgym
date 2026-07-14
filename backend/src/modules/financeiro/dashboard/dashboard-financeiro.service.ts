import { Injectable } from '@nestjs/common';
import { DashboardResumoQueryDto } from './dto/dashboard-resumo-query.dto';
import { DashboardResumoResponseDto } from './dto/dashboard-resumo-response.dto';
import { DashboardEvolucaoQueryDto } from './dto/dashboard-evolucao-query.dto';
import { DashboardEvolucaoResponseDto } from './dto/dashboard-evolucao-response.dto';
import { MensalidadesService } from '../mensalidades/mensalidades.service';
import { LancamentosService } from '../lancamentos/lancamentos.service';
import { mesRecuado } from '../financeiro.util';

/// Orquestra `MensalidadesService`/`LancamentosService` — nenhuma regra de
/// negócio nova aqui, só composição (docs/17, seção "MS5"). Existe pra
/// reduzir o Painel Financeiro a 2 chamadas HTTP em vez de 3+ que o
/// frontend precisaria fazer chamando cada serviço separadamente.
@Injectable()
export class DashboardFinanceiroService {
  constructor(
    private readonly mensalidadesService: MensalidadesService,
    private readonly lancamentosService: LancamentosService,
  ) {}

  async resumo(query: DashboardResumoQueryDto): Promise<DashboardResumoResponseDto> {
    const agora = new Date();
    const mes = query.mes ?? agora.getUTCMonth() + 1;
    const ano = query.ano ?? agora.getUTCFullYear();

    const [receitaPrevista, resumoLancamentos, inadimplencia] = await Promise.all([
      this.mensalidadesService.receitaPrevista(mes, ano),
      this.lancamentosService.resumo({ mes, ano }),
      this.mensalidadesService.inadimplencia(),
    ]);

    return {
      mes,
      ano,
      receitaPrevista: receitaPrevista.valor,
      receitaRecebida: resumoLancamentos.totalReceitas,
      despesas: resumoLancamentos.totalDespesas,
      saldo: resumoLancamentos.saldo,
      inadimplenciaValor: inadimplencia.valor,
      inadimplenciaQuantidade: inadimplencia.quantidade,
    };
  }

  async evolucao(query: DashboardEvolucaoQueryDto): Promise<DashboardEvolucaoResponseDto> {
    const agora = new Date();
    const mesAncora = query.mes ?? agora.getUTCMonth() + 1;
    const anoAncora = query.ano ?? agora.getUTCFullYear();
    const quantidadeMeses = query.meses ?? 6;

    const janela = Array.from({ length: quantidadeMeses }, (_, i) =>
      mesRecuado(mesAncora, anoAncora, i),
    );

    const meses = await Promise.all(
      janela.map(async ({ mes, ano }) => {
        const [receitaPrevista, resumoLancamentos] = await Promise.all([
          this.mensalidadesService.receitaPrevista(mes, ano),
          this.lancamentosService.resumo({ mes, ano }),
        ]);

        return {
          mes,
          ano,
          receitaPrevista: receitaPrevista.valor,
          receitaRecebida: resumoLancamentos.totalReceitas,
          despesas: resumoLancamentos.totalDespesas,
          saldo: resumoLancamentos.saldo,
        };
      }),
    );

    return { meses };
  }
}
