import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class TrancarMatriculaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  motivo?: string;
}
