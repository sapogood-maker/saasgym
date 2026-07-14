import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

export class AprovarSolicitacaoReposicaoDto {
  @ApiProperty({ description: 'Aula futura com vaga escolhida pela recepção no momento da aprovação' })
  @IsUUID()
  aulaDestinoId!: string;
}
