import { ApiProperty } from '@nestjs/swagger';

export class PlanoSaasResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  nome!: string;

  @ApiProperty()
  ativo!: boolean;

  @ApiProperty({ nullable: true })
  ordem!: number | null;

  @ApiProperty({ nullable: true })
  limiteAlunos!: number | null;

  @ApiProperty({ nullable: true })
  limiteProfessores!: number | null;

  @ApiProperty({ nullable: true })
  limiteUsuarios!: number | null;

  @ApiProperty({ nullable: true })
  limiteArmazenamentoMb!: number | null;

  @ApiProperty({ nullable: true })
  limiteBackups!: number | null;

  @ApiProperty({ nullable: true, type: Object })
  funcionalidades!: Record<string, unknown> | null;
}
