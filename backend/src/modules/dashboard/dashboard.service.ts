import { Injectable } from '@nestjs/common';
import { Prisma, UserStatus } from '@prisma/client';
import { DashboardAcademiaResponseDto } from './dto/dashboard-academia-response.dto';
import { TenantContextService } from '../../common/context/tenant-context.service';
import { PrismaService } from '../../prisma/prisma.service';
import { AulasService } from '../agenda/aulas/aulas.service';
import { DashboardFinanceiroService } from '../financeiro/dashboard/dashboard-financeiro.service';
import { MensalidadesService } from '../financeiro/mensalidades/mensalidades.service';

/// Janela da "Agenda da semana" e dos "próximos vencimentos" (docs/22,
/// decisões 1/3) — um único conceito de "semana operacional" pra tela
/// inteira, não dois recortes de tamanho diferente.
const DIAS_JANELA_SEMANA = 7;

/// Teto de segurança da lista de aulas da semana (docs/22, decisão 5) —
/// mesma lógica defensiva de `ALUNOS_NOVOS_LIMITE`, só que numa janela
/// maior (7 dias em vez de 1).
const AULAS_SEMANA_LIMITE = 100;

interface AniversarianteRow {
  id: string;
  nome: string;
  dataNascimento: Date;
}

// Limite de itens do "Alunos novos" do Dashboard — lista curta e acionável,
// não uma paginação completa (essa já existe na tela de Alunos).
const ALUNOS_NOVOS_LIMITE = 5;

@Injectable()
export class DashboardService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tenantContext: TenantContextService,
    private readonly aulasService: AulasService,
    private readonly dashboardFinanceiroService: DashboardFinanceiroService,
    private readonly mensalidadesService: MensalidadesService,
  ) {}

  async get(): Promise<DashboardAcademiaResponseDto> {
    const academiaId = this.tenantContext.getAcademiaId() as string;
    const inicioMes = new Date();
    inicioMes.setDate(1);
    inicioMes.setHours(0, 0, 0, 0);
    // `Aula.data` é sempre meia-noite UTC do dia (mesma construção de
    // `dataVencimentoNoMes`/`intervaloDoMes` no Financeiro) — a janela
    // precisa ser truncada pro dia em UTC, não a hora corrente, senão
    // aulas de hoje anteriores ao horário atual ficariam de fora do
    // filtro `gte` (docs/22, "Fuso horário de hoje/semana").
    const agora = new Date();
    const hoje = new Date(Date.UTC(agora.getUTCFullYear(), agora.getUTCMonth(), agora.getUTCDate()));
    const fimJanelaSemana = new Date(hoje.getTime() + DIAS_JANELA_SEMANA * 24 * 60 * 60 * 1000);

    const [
      totalAlunos,
      alunosAtivos,
      totalProfessores,
      novosAlunosMes,
      aniversariantes,
      usuariosDoSistema,
      alunosNovos,
      aulasSemana,
      resumoFinanceiro,
      mensalidadesAlerta,
    ] = await Promise.all([
      this.prisma.forTenant().aluno.count({ where: { deletedAt: null } }),
      this.prisma.forTenant().aluno.count({ where: { deletedAt: null, status: UserStatus.ATIVO } }),
      this.prisma.forTenant().professor.count({ where: { deletedAt: null } }),
      this.prisma
        .forTenant()
        .aluno.count({ where: { deletedAt: null, createdAt: { gte: inicioMes } } }),
      this.buscarAniversariantesDoMes(academiaId),
      this.prisma.forTenant().user.count(),
      this.prisma.forTenant().aluno.findMany({
        where: { deletedAt: null, createdAt: { gte: inicioMes } },
        orderBy: { createdAt: 'desc' },
        take: ALUNOS_NOVOS_LIMITE,
        select: { id: true, nome: true, createdAt: true },
      }),
      this.aulasService.listCalendario({
        dataInicio: hoje.toISOString(),
        dataFim: fimJanelaSemana.toISOString(),
        page: 1,
        pageSize: AULAS_SEMANA_LIMITE,
      }),
      this.dashboardFinanceiroService.resumo({}),
      this.mensalidadesService.proximosVencimentos(DIAS_JANELA_SEMANA),
    ]);

    return {
      totalAlunos,
      alunosAtivos,
      totalProfessores,
      novosAlunosMes,
      aniversariantes,
      usuariosDoSistema,
      alunosNovos,
      aulasSemana: aulasSemana.items,
      financeiro: {
        receitaPrevista: resumoFinanceiro.receitaPrevista,
        receitaRecebida: resumoFinanceiro.receitaRecebida,
        despesas: resumoFinanceiro.despesas,
        saldo: resumoFinanceiro.saldo,
        inadimplenciaValor: resumoFinanceiro.inadimplenciaValor,
        inadimplenciaQuantidade: resumoFinanceiro.inadimplenciaQuantidade,
        mensalidadesAlerta,
      },
    };
  }

  /// Prisma não expressa "mês de uma data, ignorando o ano" no query
  /// builder — precisa de SQL bruto. $queryRaw com template tag
  /// parametriza academiaId automaticamente (nunca concatenação de
  /// string); como SQL bruto não passa pela extensão de tenant, o filtro
  /// por academiaId aqui é manual e obrigatório.
  private async buscarAniversariantesDoMes(academiaId: string): Promise<AniversarianteRow[]> {
    return this.prisma.$queryRaw<AniversarianteRow[]>(Prisma.sql`
      SELECT id, nome, "dataNascimento"
      FROM alunos
      WHERE "academiaId" = ${academiaId}
        AND "deletedAt" IS NULL
        AND EXTRACT(MONTH FROM "dataNascimento") = EXTRACT(MONTH FROM CURRENT_DATE)
      ORDER BY EXTRACT(DAY FROM "dataNascimento") ASC
    `);
  }
}
