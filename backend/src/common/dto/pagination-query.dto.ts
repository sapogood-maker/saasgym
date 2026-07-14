import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

/// `page`/`pageSize` idênticos em toda listagem paginada do produto —
/// puramente mecânico (sem regra de domínio), por isso é o único caso de
/// extração de DTO que vale a pena (Sprint de Consolidação do Módulo 4).
/// O único endpoint com paginação maior (Calendário, `pageSize` até 200)
/// mantém sua própria declaração em vez de estender esta classe: redeclarar
/// `pageSize` numa subclasse faria os decorators do `class-validator` da
/// classe base e da subclasse acumularem (a metadata é agregada em toda a
/// cadeia de protótipos), então o `@Max(100)` daqui continuaria valendo
/// junto do `@Max(200)` da subclasse — um resultado pior, não melhor.
export class PaginationQueryDto {
  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page: number = 1;

  @ApiPropertyOptional({ default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize: number = 20;
}
