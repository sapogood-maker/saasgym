import { ApiProperty } from '@nestjs/swagger';

export class AcademiaConfiguracaoResponseDto {
  @ApiProperty()
  academiaId!: string;

  @ApiProperty({ nullable: true })
  logoUrl!: string | null;

  @ApiProperty({ nullable: true, type: Object })
  temaCores!: Record<string, unknown> | null;

  @ApiProperty({ nullable: true })
  whatsapp!: string | null;

  @ApiProperty({ nullable: true })
  instagram!: string | null;

  @ApiProperty({ nullable: true })
  facebook!: string | null;

  @ApiProperty({ nullable: true })
  pix!: string | null;

  @ApiProperty({ nullable: true, type: Object })
  horarioFuncionamento!: Record<string, unknown> | null;
}
