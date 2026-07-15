import { ApiProperty } from '@nestjs/swagger';
import { AulaResponseDto } from '../../agenda/aulas/dto/aula-response.dto';
import { MensalidadeAlertaResponseDto } from '../../financeiro/mensalidades/dto/mensalidade-alerta-response.dto';

class AniversarianteDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  nome!: string;

  @ApiProperty()
  dataNascimento!: Date;
}

class AlunoRecenteDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  nome!: string;

  @ApiProperty()
  createdAt!: Date;
}

class DashboardFinanceiroResumoDto {
  @ApiProperty({ description: 'Soma de Matricula.valor das ATIVA cuja vigência cobre o mês corrente' })
  receitaPrevista!: number;

  @ApiProperty({ description: 'Soma de Lancamento tipo RECEITA do mês corrente' })
  receitaRecebida!: number;

  @ApiProperty()
  despesas!: number;

  @ApiProperty({ description: 'receitaRecebida - despesas' })
  saldo!: number;

  @ApiProperty({ description: 'Sempre tempo real — todas as Mensalidade PENDENTE vencidas até hoje' })
  inadimplenciaValor!: number;

  @ApiProperty()
  inadimplenciaQuantidade!: number;

  @ApiProperty({
    type: [MensalidadeAlertaResponseDto],
    description: 'Vencidas + a vencer nos próximos 7 dias, combinadas e capadas em 10 (docs/22)',
  })
  mensalidadesAlerta!: MensalidadeAlertaResponseDto[];
}

/// Dashboard da própria academia — Centro de Operações (docs/22) —
/// distinto do dashboard do SYSTEM_ADMIN (Sprint 2, /admin/dashboard,
/// visão cross-tenant da plataforma).
export class DashboardAcademiaResponseDto {
  @ApiProperty()
  totalAlunos!: number;

  @ApiProperty()
  alunosAtivos!: number;

  @ApiProperty()
  totalProfessores!: number;

  @ApiProperty()
  novosAlunosMes!: number;

  @ApiProperty({ type: [AniversarianteDto] })
  aniversariantes!: AniversarianteDto[];

  @ApiProperty()
  usuariosDoSistema!: number;

  /// Últimos alunos cadastrados no mês corrente (mesmo recorte de
  /// `novosAlunosMes`), limitado a 5 — vira lista acionável no Dashboard
  /// em vez de só uma contagem.
  @ApiProperty({ type: [AlunoRecenteDto] })
  alunosNovos!: AlunoRecenteDto[];

  /// Aulas dos próximos 7 dias (hoje incluso), reaproveitando o mesmo
  /// shape de `AulaResponseDto` do Calendário — agrupamento por dia é
  /// responsabilidade do frontend (docs/22, decisão 5).
  @ApiProperty({ type: [AulaResponseDto] })
  aulasSemana!: AulaResponseDto[];

  @ApiProperty({ type: DashboardFinanceiroResumoDto })
  financeiro!: DashboardFinanceiroResumoDto;
}
