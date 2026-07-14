import { ApiProperty } from '@nestjs/swagger';

export class GerarAulasResponseDto {
  @ApiProperty({ description: 'Quantidade de Aulas novas criadas nesta rodada' })
  geradas!: number;

  @ApiProperty({ description: 'Quantidade de datas candidatas que já tinham Aula e foram puladas' })
  jaExistentes!: number;
}
