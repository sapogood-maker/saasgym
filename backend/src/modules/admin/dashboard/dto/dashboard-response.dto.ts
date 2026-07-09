import { ApiProperty } from '@nestjs/swagger';

class AcademiasPorStatusDto {
  @ApiProperty()
  TRIAL!: number;

  @ApiProperty()
  ATIVA!: number;

  @ApiProperty()
  SUSPENSA!: number;

  @ApiProperty()
  BLOQUEADA!: number;

  @ApiProperty()
  CANCELADA!: number;
}

class BackupsInfoDto {
  @ApiProperty({ description: 'Módulo de backup ainda não existe — sempre false nesta sprint' })
  disponivel!: boolean;

  @ApiProperty()
  quantidade!: number;
}

export class DashboardResponseDto {
  @ApiProperty()
  totalAcademias!: number;

  @ApiProperty({ type: AcademiasPorStatusDto })
  academiasPorStatus!: AcademiasPorStatusDto;

  @ApiProperty({ description: 'Soma real de Arquivo.tamanhoBytes' })
  armazenamentoUsadoBytes!: number;

  @ApiProperty({ type: BackupsInfoDto })
  backups!: BackupsInfoDto;

  @ApiProperty()
  versaoInstalada!: string;
}
