import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { MensalidadeStatus } from '@prisma/client';
import { IsEnum, IsInt, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';
import { PaginationQueryDto } from '../../../../common/dto/pagination-query.dto';

export class ListMensalidadesQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Pesquisa por nome do aluno (contains, case-insensitive) — complemento à navegação por competência' })
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional({ description: 'Filtra por matrícula' })
  @IsOptional()
  @IsUUID()
  matriculaId?: string;

  @ApiPropertyOptional({ description: 'Filtra por aluno' })
  @IsOptional()
  @IsUUID()
  alunoId?: string;

  @ApiPropertyOptional({ enum: MensalidadeStatus })
  @IsOptional()
  @IsEnum(MensalidadeStatus)
  status?: MensalidadeStatus;

  @ApiPropertyOptional({ description: 'Filtra pelo mês de vencimento (1-12) — exige "ano" junto' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(12)
  mes?: number;

  @ApiPropertyOptional({ description: 'Filtra pelo ano de vencimento — exige "mes" junto' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(2000)
  ano?: number;
}
