import { ApiPropertyOptional } from '@nestjs/swagger';
import { SolicitacaoReposicaoStatus } from '@prisma/client';
import { IsEnum, IsOptional, IsUUID } from 'class-validator';
import { PaginationQueryDto } from '../../../../common/dto/pagination-query.dto';

export class ListSolicitacoesReposicaoQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: SolicitacaoReposicaoStatus })
  @IsOptional()
  @IsEnum(SolicitacaoReposicaoStatus)
  status?: SolicitacaoReposicaoStatus;

  @ApiPropertyOptional({ description: 'Filtra por aluno' })
  @IsOptional()
  @IsUUID()
  alunoId?: string;
}
