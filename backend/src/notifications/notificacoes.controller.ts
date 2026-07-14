import { Controller, Get, Param, ParseUUIDPipe, Patch, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { NotificacoesService } from './notificacoes.service';
import { ListNotificacoesQueryDto } from './dto/list-notificacoes-query.dto';
import { NotificacaoResponseDto, PaginatedNotificacoesResponseDto } from './dto/notificacao-response.dto';
import { AcademiaGuard } from '../common/guards/academia.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../common/types/authenticated-user.interface';

/// "Minhas notificações" — sempre o usuário autenticado, nunca outro
/// (mesmo padrão de `/users/me`). Sem `@Roles()`: qualquer papel autenticado
/// da academia pode ver e marcar como lidas as próprias notificações.
@ApiTags('notificacoes')
@ApiBearerAuth()
@UseGuards(AcademiaGuard)
@Controller('notificacoes')
export class NotificacoesController {
  constructor(private readonly service: NotificacoesService) {}

  @Get()
  @ApiOperation({ summary: 'Lista as notificações do usuário autenticado — não lidas primeiro' })
  list(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: ListNotificacoesQueryDto,
  ): Promise<PaginatedNotificacoesResponseDto> {
    return this.service.listMinhas(user.userId, query);
  }

  @Patch(':id/lida')
  @ApiOperation({ summary: 'Marca uma notificação como lida' })
  marcarComoLida(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<NotificacaoResponseDto> {
    return this.service.marcarComoLida(user.userId, id);
  }
}
