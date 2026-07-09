import { Injectable } from '@nestjs/common';
import { Prisma, UserStatus } from '@prisma/client';
import { DashboardAcademiaResponseDto } from './dto/dashboard-academia-response.dto';
import { TenantContextService } from '../../common/context/tenant-context.service';
import { PrismaService } from '../../prisma/prisma.service';

interface AniversarianteRow {
  id: string;
  nome: string;
  dataNascimento: Date;
}

@Injectable()
export class DashboardService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tenantContext: TenantContextService,
  ) {}

  async get(): Promise<DashboardAcademiaResponseDto> {
    const academiaId = this.tenantContext.getAcademiaId() as string;
    const inicioMes = new Date();
    inicioMes.setDate(1);
    inicioMes.setHours(0, 0, 0, 0);

    const [
      totalAlunos,
      alunosAtivos,
      totalProfessores,
      novosAlunosMes,
      aniversariantes,
      usuariosDoSistema,
    ] = await Promise.all([
      this.prisma.forTenant().aluno.count({ where: { deletedAt: null } }),
      this.prisma.forTenant().aluno.count({ where: { deletedAt: null, status: UserStatus.ATIVO } }),
      this.prisma.forTenant().professor.count({ where: { deletedAt: null } }),
      this.prisma
        .forTenant()
        .aluno.count({ where: { deletedAt: null, createdAt: { gte: inicioMes } } }),
      this.buscarAniversariantesDoMes(academiaId),
      this.prisma.forTenant().user.count(),
    ]);

    return {
      totalAlunos,
      alunosAtivos,
      totalProfessores,
      novosAlunosMes,
      aniversariantes,
      usuariosDoSistema,
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
