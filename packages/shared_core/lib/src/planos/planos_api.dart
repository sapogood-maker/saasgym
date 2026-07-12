import 'plano.dart';
import '../common/crud_api.dart';

/// Primeira entidade a nascer diretamente sobre `CrudApi<T>` — sem
/// `uploadFoto` (Plano não tem foto).
class PlanosApi extends CrudApi<Plano> {
  PlanosApi(super.dio) : super(resourcePath: '/planos', fromJson: Plano.fromJson);
}
