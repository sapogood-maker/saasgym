/// Espelha o enum `FormaPagamento` do backend (Prisma) — como uma
/// Mensalidade/Lancamento foi paga/recebida.
enum FormaPagamento {
  dinheiro('DINHEIRO'),
  pix('PIX'),
  cartaoCredito('CARTAO_CREDITO'),
  cartaoDebito('CARTAO_DEBITO'),
  boleto('BOLETO'),
  outro('OUTRO');

  const FormaPagamento(this.wireValue);

  final String wireValue;

  static FormaPagamento fromJson(String value) {
    return FormaPagamento.values.firstWhere(
      (forma) => forma.wireValue == value,
      orElse: () => throw ArgumentError('Forma de pagamento desconhecida: $value'),
    );
  }

  String toJson() => wireValue;
}
