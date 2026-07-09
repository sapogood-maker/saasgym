import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsObject, IsOptional, IsString } from 'class-validator';

export class UpdateAcademiaConfiguracaoDto {
  @ApiPropertyOptional({ description: 'Ex.: { "primaria": "#0055FF", "secundaria": "#111827" }' })
  @IsOptional()
  @IsObject()
  temaCores?: Record<string, unknown>;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  whatsapp?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  instagram?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  facebook?: string;

  @ApiPropertyOptional({ description: 'Chave PIX' })
  @IsOptional()
  @IsString()
  pix?: string;

  @ApiPropertyOptional({ description: 'Ex.: { "seg": "06:00-22:00", "ter": "06:00-22:00" }' })
  @IsOptional()
  @IsObject()
  horarioFuncionamento?: Record<string, unknown>;
}
