import 'turma.dart';
import '../common/crud_api.dart';

/// CRUD puro sobre `CrudApi<T>` — mesmo caso de `PlanosApi`/`ModalidadesApi`.
/// Nenhum método próprio: `list`/`get`/`create`/`update`/`updateStatus`/
/// `remove` cobrem 100% do endpoint do MS3. Recorrência/Aula/matrícula em
/// turma **não** entram aqui — sem antecipar API que os MS seguintes ainda
/// não implementaram no backend.
class TurmasApi extends CrudApi<Turma> {
  TurmasApi(super.dio) : super(resourcePath: '/agenda/turmas', fromJson: Turma.fromJson);
}
