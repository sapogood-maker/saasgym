import { PaginationQueryDto } from '../../common/dto/pagination-query.dto';

/// Sem filtro de `lida` — a listagem já vem ordenada não-lidas primeiro
/// (ver `NotificacoesService.listMinhas`), e a resposta paginada já traz
/// `naoLidas` (total) pro badge do sino — nenhum 2º endpoint necessário.
export class ListNotificacoesQueryDto extends PaginationQueryDto {}
