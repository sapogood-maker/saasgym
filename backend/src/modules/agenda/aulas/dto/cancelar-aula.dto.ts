import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class CancelarAulaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  motivoCancelamento?: string;
}
