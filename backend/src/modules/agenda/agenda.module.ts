import { Module } from '@nestjs/common';
import { ModalidadesController } from './modalidades/modalidades.controller';
import { ModalidadesService } from './modalidades/modalidades.service';
import { FeriadosController } from './feriados/feriados.controller';
import { FeriadosService } from './feriados/feriados.service';
import { TurmasController } from './turmas/turmas.controller';
import { TurmasService } from './turmas/turmas.service';
import { RecorrenciasController } from './recorrencias/recorrencias.controller';
import { RecorrenciasService } from './recorrencias/recorrencias.service';
import { TurmaAlunosController } from './turma-alunos/turma-alunos.controller';
import { TurmaAlunosService } from './turma-alunos/turma-alunos.service';
import { AulasController } from './aulas/aulas.controller';
import { AulasCalendarioController } from './aulas/aulas-calendario.controller';
import { AulasService } from './aulas/aulas.service';
import { AulaAlunosController } from './aula-alunos/aula-alunos.controller';
import { AulaAlunosService } from './aula-alunos/aula-alunos.service';
import { AuditModule } from '../audit/audit.module';

/// Agrupa Modalidades/Feriados (MS1) + Turmas (MS3) + Recorrencias (MS4) +
/// TurmaAlunos (MS5) + Aulas/Calendário (MS6/MS7) + Frequência (MS8) —
/// mesmo padrão de FinanceiroModule agregando mensalidades/lancamentos.
/// Subpastas são só organização de arquivo, não módulos Nest próprios.
@Module({
  imports: [AuditModule],
  controllers: [
    ModalidadesController,
    FeriadosController,
    TurmasController,
    RecorrenciasController,
    TurmaAlunosController,
    AulasController,
    AulasCalendarioController,
    AulaAlunosController,
  ],
  providers: [
    ModalidadesService,
    FeriadosService,
    TurmasService,
    RecorrenciasService,
    TurmaAlunosService,
    AulasService,
    AulaAlunosService,
  ],
})
export class AgendaModule {}
