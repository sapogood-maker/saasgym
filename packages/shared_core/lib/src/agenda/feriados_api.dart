import 'feriado.dart';
import '../common/crud_api.dart';

/// CRUD puro sobre `CrudApi<T>` — `list`/`get`/`create`/`update`/`remove`
/// cobrem 100% do endpoint. `updateStatus` continua herdado mas não se
/// aplica (Feriado não tem campo de status); o filtro `status` de
/// `list()` também não é usado por este recurso — nenhum dos dois é
/// chamado por quem consome esta API, mesmo padrão já documentado em
/// `MensalidadesApi`/`LancamentosApi` para membros herdados sem uso.
class FeriadosApi extends CrudApi<Feriado> {
  FeriadosApi(super.dio) : super(resourcePath: '/agenda/feriados', fromJson: Feriado.fromJson);
}
