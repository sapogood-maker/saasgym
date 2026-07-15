import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navegação de "voltar" das telas de detalhe/formulário fora do
/// `ShellRoute` (docs/26) — usada tanto pelo `PopScope` de cada tela
/// (botão do sistema/navegador) quanto pelo `AppDetailHeader.onBack`
/// (link "← Lista"), sempre pelo mesmo caminho, nunca dois métodos de
/// saída divergentes.
extension AppBackNavigation on BuildContext {
  /// Volta pra lista de origem preservando filtro/busca/página: quando
  /// esta tela foi aberta via `push()` a partir da lista (o caso normal —
  /// sempre é, hoje), a instância da lista continua viva na pilha e
  /// `pop(result)` devolve pra ela sem refetch. Só cai em `go(listRoute)`
  /// quando não há nada pra "pop" (entrada direta por URL/reload) — nesse
  /// caso não existe filtro nenhum salvo pra preservar.
  void backToList(String listRoute, {Object? result}) {
    if (canPop()) {
      pop(result);
    } else {
      go(listRoute);
    }
  }
}
