import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Injectable } from '@nestjs/common';
import { AcademiaStatus } from '@prisma/client';
import { DashboardResponseDto } from './dto/dashboard-response.dto';
import { PrismaService } from '../../../prisma/prisma.service';

const TODOS_OS_STATUS = Object.values(AcademiaStatus);

@Injectable()
export class AdminDashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async get(): Promise<DashboardResponseDto> {
    const [totalAcademias, contagensPorStatus, armazenamento] = await Promise.all([
      this.prisma.academia.count(),
      this.prisma.academia.groupBy({ by: ['status'], _count: true }),
      this.prisma.arquivo.aggregate({ _sum: { tamanhoBytes: true } }),
    ]);

    const academiasPorStatus = Object.fromEntries(
      TODOS_OS_STATUS.map((status) => [status, 0]),
    ) as Record<AcademiaStatus, number>;
    for (const linha of contagensPorStatus) {
      academiasPorStatus[linha.status] = linha._count;
    }

    return {
      totalAcademias,
      academiasPorStatus,
      armazenamentoUsadoBytes: armazenamento._sum.tamanhoBytes ?? 0,
      // Módulo de backup ainda não existe (ver docs/08-roadmap.md) — honesto
      // em vez de inventar um número.
      backups: { disponivel: false, quantidade: 0 },
      versaoInstalada: this.getVersaoInstalada(),
    };
  }

  private getVersaoInstalada(): string {
    try {
      const pkg = JSON.parse(readFileSync(join(process.cwd(), 'package.json'), 'utf-8')) as {
        version?: string;
      };
      return pkg.version ?? 'desconhecida';
    } catch {
      return 'desconhecida';
    }
  }
}
