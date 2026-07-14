import { ApiProperty } from '@nestjs/swagger';
import { SolicitacaoReposicaoStatus } from '@prisma/client';

export class SolicitacaoReposicaoResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  alunoId!: string;

  @ApiProperty()
  alunoNome!: string;

  @ApiProperty()
  aulaAlunoOrigemId!: string;

  @ApiProperty({ description: 'Data da aula perdida' })
  aulaOrigemData!: Date;

  @ApiProperty()
  aulaOrigemTurmaNome!: string;

  @ApiProperty({ nullable: true, description: 'Nulo até a aprovação' })
  aulaDestinoId!: string | null;

  @ApiProperty({ nullable: true })
  aulaDestinoData!: Date | null;

  @ApiProperty({ nullable: true })
  aulaDestinoTurmaNome!: string | null;

  @ApiProperty({ enum: SolicitacaoReposicaoStatus })
  status!: SolicitacaoReposicaoStatus;

  @ApiProperty({ nullable: true })
  observacoes!: string | null;

  @ApiProperty({ nullable: true })
  motivoRejeicao!: string | null;

  @ApiProperty()
  createdByUserId!: string;

  @ApiProperty()
  createdByUserNome!: string;

  @ApiProperty({ nullable: true })
  decidedByUserId!: string | null;

  @ApiProperty({ nullable: true })
  decidedByUserNome!: string | null;

  @ApiProperty({ nullable: true })
  decidedAt!: Date | null;

  @ApiProperty()
  createdAt!: Date;
}

export class PaginatedSolicitacoesReposicaoResponseDto {
  @ApiProperty({ type: [SolicitacaoReposicaoResponseDto] })
  items!: SolicitacaoReposicaoResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  pageSize!: number;
}
