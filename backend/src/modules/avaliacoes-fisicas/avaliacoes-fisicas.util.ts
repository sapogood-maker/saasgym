/// IMC — sempre calculado, nunca armazenado (docs/20, decisão 2). `altura`
/// chega em centímetros (mesma unidade que o usuário digita); a conversão
/// pra metros fica isolada aqui, sem vazar pra nenhum outro lugar do
/// sistema.
export function calcularImc(peso: number, alturaCm: number): number {
  const alturaM = alturaCm / 100;
  return Math.round((peso / (alturaM * alturaM)) * 10) / 10;
}
