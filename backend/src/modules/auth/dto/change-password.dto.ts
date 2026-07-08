import { ApiProperty } from '@nestjs/swagger';
import { IsString, MinLength } from 'class-validator';
import { IsStrongPassword } from '../validators/strong-password.decorator';

export class ChangePasswordDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  currentPassword!: string;

  @ApiProperty({ description: 'Mínimo 8 caracteres, com maiúscula, minúscula e número' })
  @IsStrongPassword()
  newPassword!: string;
}
