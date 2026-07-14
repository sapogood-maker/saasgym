import { ApiProperty } from '@nestjs/swagger';

export class NotificacaoResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  titulo!: string;

  @ApiProperty()
  mensagem!: string;

  @ApiProperty()
  lida!: boolean;

  @ApiProperty({ nullable: true })
  lidaEm!: Date | null;

  @ApiProperty()
  createdAt!: Date;
}

export class PaginatedNotificacoesResponseDto {
  @ApiProperty({ type: [NotificacaoResponseDto] })
  items!: NotificacaoResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  pageSize!: number;

  @ApiProperty({ description: 'Total de não lidas (não só as desta página) — pro badge do sino' })
  naoLidas!: number;
}
