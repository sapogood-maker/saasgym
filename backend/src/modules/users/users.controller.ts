import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Patch,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { UpdateUserProfileDto } from './dto/update-user-profile.dto';
import { UserProfileResponseDto } from './dto/user-profile-response.dto';
import { UsersService } from './users.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/types/authenticated-user.interface';
import { ImageFileInterceptor } from '../../common/upload/image-file-interceptor';

/// Perfil próprio — qualquer usuário autenticado, incluindo SYSTEM_ADMIN
/// (sem AcademiaGuard, mesmo padrão de /auth/me). Trocar a própria senha
/// já existe em PATCH /auth/password (Sprint 1) — não duplicado aqui.
@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(private readonly service: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Perfil do usuário autenticado' })
  me(@CurrentUser() user: AuthenticatedUser): Promise<UserProfileResponseDto> {
    return this.service.me(user.userId);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Atualiza o próprio nome (e-mail e role não são editáveis por aqui)' })
  updateMe(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpdateUserProfileDto,
  ): Promise<UserProfileResponseDto> {
    return this.service.updateMe(user.userId, dto);
  }

  @Post('me/foto')
  @ApiOperation({ summary: 'Upload do avatar do usuário (PNG/JPEG/WebP, até 2MB)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' } } },
  })
  @UseInterceptors(ImageFileInterceptor())
  async uploadFoto(
    @CurrentUser() user: AuthenticatedUser,
    @UploadedFile() file: Express.Multer.File | undefined,
  ): Promise<UserProfileResponseDto> {
    if (!file) {
      throw new BadRequestException('Nenhum arquivo enviado');
    }
    return this.service.uploadFoto(user.userId, file);
  }
}
