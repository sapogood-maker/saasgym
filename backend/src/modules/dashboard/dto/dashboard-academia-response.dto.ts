import { ApiProperty } from '@nestjs/swagger';

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

/// Dashboard da própria academia — distinto do dashboard do SYSTEM_ADMIN
/// (Sprint 2, /admin/dashboard, visão cross-tenant da plataforma). Ainda
/// sem Agenda/Financeiro (chegam em sprints futuros).
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
}
