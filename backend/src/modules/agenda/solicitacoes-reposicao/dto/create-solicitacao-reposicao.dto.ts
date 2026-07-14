import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, IsUUID } from 'class-validator';

/// Sem `aulaDestinoId` — a solicitação nasce só com a aula perdida (docs/21,
/// decisão 3). O destino só existe a partir da aprovação.
export class CreateSolicitacaoReposicaoDto {
  @ApiProperty({ description: 'AulaAluno da aula perdida (falta ou aula cancelada)' })
  @IsUUID()
  aulaAlunoOrigemId!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacoes?: string;
}
