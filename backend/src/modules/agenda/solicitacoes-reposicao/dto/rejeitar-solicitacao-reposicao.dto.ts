import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class RejeitarSolicitacaoReposicaoDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  motivoRejeicao?: string;
}
