import { ApiPropertyOptional, ApiProperty } from '@nestjs/swagger';
import { FormaPagamento } from '@prisma/client';
import { IsDateString, IsEnum, IsOptional } from 'class-validator';

export class MarcarPagaMensalidadeDto {
  @ApiProperty({ enum: FormaPagamento })
  @IsEnum(FormaPagamento)
  formaPagamento!: FormaPagamento;

  @ApiPropertyOptional({ description: 'ISO 8601. Default: agora' })
  @IsOptional()
  @IsDateString()
  dataPagamento?: string;
}
