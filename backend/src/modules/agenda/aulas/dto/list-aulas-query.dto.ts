import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsOptional } from 'class-validator';
import { PaginationQueryDto } from '../../../../common/dto/pagination-query.dto';

export class ListAulasQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Filtra aulas com data >= dataInicio' })
  @IsOptional()
  @IsDateString()
  dataInicio?: string;

  @ApiPropertyOptional({ description: 'Filtra aulas com data <= dataFim' })
  @IsOptional()
  @IsDateString()
  dataFim?: string;
}
