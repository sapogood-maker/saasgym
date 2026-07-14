import 'modalidade.dart';
import '../common/crud_api.dart';

/// CRUD puro sobre `CrudApi<T>` — mesmo caso de `PlanosApi` (list/get/
/// create/update/updateStatus/remove cobrem 100% do endpoint, nenhum
/// método próprio necessário).
class ModalidadesApi extends CrudApi<Modalidade> {
  ModalidadesApi(super.dio)
    : super(resourcePath: '/agenda/modalidades', fromJson: Modalidade.fromJson);
}
