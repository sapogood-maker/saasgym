import { ApiProperty } from '@nestjs/swagger';
import { Role } from '@prisma/client';

export class UserProfileResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  nome!: string;

  @ApiProperty()
  email!: string;

  @ApiProperty({ enum: Role })
  role!: Role;

  @ApiProperty({ nullable: true })
  academiaId!: string | null;

  @ApiProperty({ nullable: true })
  fotoUrl!: string | null;
}
