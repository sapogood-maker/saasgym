import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { AcademiaStatus } from '@prisma/client';
import { IsEnum, IsOptional, IsString } from 'class-validator';

export class UpdateAcademiaStatusDto {
  @ApiProperty({ enum: AcademiaStatus })
  @IsEnum(AcademiaStatus)
  status!: AcademiaStatus;

  @ApiPropertyOptional({ description: 'Vai para o metadata da auditoria' })
  @IsOptional()
  @IsString()
  motivo?: string;
}
