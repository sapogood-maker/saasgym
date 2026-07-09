import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsEmail,
  IsNotEmptyObject,
  IsOptional,
  IsString,
  IsUUID,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { IsStrongPassword } from '../../../auth/validators/strong-password.decorator';

export class CreateAcademiaAdminInicialDto {
  @ApiProperty()
  @IsString()
  @MinLength(2)
  nome!: string;

  @ApiProperty()
  @IsEmail()
  email!: string;

  @ApiProperty({ description: 'Mínimo 8 caracteres, com maiúscula, minúscula e número' })
  @IsStrongPassword()
  senha!: string;
}

export class CreateAcademiaDto {
  @ApiProperty()
  @IsString()
  @MinLength(2)
  nome!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  cnpj?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  telefone?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  endereco?: string;

  @ApiPropertyOptional({ description: 'Subdomínio futuro — sem uso ainda' })
  @IsOptional()
  @IsString()
  dominio?: string;

  @ApiPropertyOptional({ description: 'Se omitido, usa o plano "Trial" padrão' })
  @IsOptional()
  @IsUUID()
  planoSaasId?: string;

  // @ValidateNested() sozinho não torna o campo obrigatório — se ausente,
  // passa como undefined sem erro de validação. @IsNotEmptyObject() fecha
  // esse buraco.
  @ApiProperty({ type: CreateAcademiaAdminInicialDto })
  @IsNotEmptyObject()
  @ValidateNested()
  @Type(() => CreateAcademiaAdminInicialDto)
  adminInicial!: CreateAcademiaAdminInicialDto;
}
