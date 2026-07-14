import { ApiPropertyOptional } from '@nestjs/swagger';
import { AcademiaStatus } from '@prisma/client';
import { IsEnum, IsOptional } from 'class-validator';
import { PaginationQueryDto } from '../../../../common/dto/pagination-query.dto';

export class ListAcademiasQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: AcademiaStatus })
  @IsOptional()
  @IsEnum(AcademiaStatus)
  status?: AcademiaStatus;
}
