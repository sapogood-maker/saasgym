import { ApiPropertyOptional } from '@nestjs/swagger';
import { MatriculaStatus } from '@prisma/client';
import { IsEnum, IsOptional, IsString, IsUUID } from 'class-validator';
import { PaginationQueryDto } from '../../../common/dto/pagination-query.dto';

export class ListMatriculasQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Pesquisa por nome do aluno (contains, case-insensitive)' })
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional({ description: 'Filtra por aluno' })
  @IsOptional()
  @IsUUID()
  alunoId?: string;

  @ApiPropertyOptional({ description: 'Filtra por plano' })
  @IsOptional()
  @IsUUID()
  planoId?: string;

  @ApiPropertyOptional({ enum: MatriculaStatus })
  @IsOptional()
  @IsEnum(MatriculaStatus)
  status?: MatriculaStatus;
}
