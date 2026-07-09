import { ApiProperty } from '@nestjs/swagger';
import { IsString, MinLength } from 'class-validator';

/// Autoatendimento — só nome. E-mail (identificador de login) e role
/// nunca são editáveis por aqui: e-mail exigiria reverificação, e role é
/// explicitamente vedado pelo escopo desta sprint ("sem permitir alterar
/// permissões").
export class UpdateUserProfileDto {
  @ApiProperty()
  @IsString()
  @MinLength(2)
  nome!: string;
}
