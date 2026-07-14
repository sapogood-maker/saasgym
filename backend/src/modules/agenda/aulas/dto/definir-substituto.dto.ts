import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

/// Exceção pontual da Aula (docs/18, seção 5, "Calendário — invariante
/// 3") — só escreve `Aula.professorId`; nunca `Turma.professorId` nem
/// `Recorrencia.professorId`.
export class DefinirSubstitutoDto {
  @ApiProperty({ description: 'Professor substituto para esta ocorrência' })
  @IsUUID()
  professorId!: string;
}
