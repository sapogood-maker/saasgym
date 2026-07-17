import { BadRequestException } from '@nestjs/common';
import { ValidationError } from 'class-validator';

/// Traduz pela CHAVE da constraint (`isString`, `minLength`...), nunca
/// pelo texto da mensagem original — a chave é estável entre versões do
/// class-validator (confirmado empiricamente contra a versão instalada),
/// o texto em si não é contrato nenhum. Decorators que já registram sua
/// própria mensagem em português (`@IsCPF()`, `@IsStrongPassword()`,
/// `@Matches()` neste projeto) usam nomes de constraint que não aparecem
/// aqui de propósito — o fallback em `traduzirErro` devolve a mensagem
/// original sem alterar, então eles continuam corretos sem precisar de
/// entrada nesta lista.
const TRADUCOES: Record<string, (campo: string, numero?: string) => string> = {
  isString: (campo) => `${campo} deve ser texto`,
  isNotEmpty: (campo) => `${campo} é obrigatório`,
  minLength: (campo, n) => `${campo} deve ter no mínimo ${n} caracteres`,
  maxLength: (campo, n) => `${campo} deve ter no máximo ${n} caracteres`,
  isEmail: (campo) => `${campo} deve ser um e-mail válido`,
  isEnum: (campo) => `${campo} tem um valor inválido`,
  isInt: (campo) => `${campo} deve ser um número inteiro`,
  isNumber: (campo) => `${campo} deve ser um número`,
  min: (campo, n) => `${campo} não pode ser menor que ${n}`,
  max: (campo, n) => `${campo} não pode ser maior que ${n}`,
  isPositive: (campo) => `${campo} deve ser maior que zero`,
  isUuid: (campo) => `${campo} é inválido`,
  isDateString: (campo) => `${campo} deve ser uma data válida`,
  isBoolean: (campo) => `${campo} deve ser verdadeiro ou falso`,
  isHexColor: (campo) => `${campo} deve ser uma cor no formato #RRGGBB`,
  isObject: (campo) => `${campo} deve ser um objeto`,
  isNotEmptyObject: (campo) => `${campo} não pode estar vazio`,
  // `forbidNonWhitelisted: true` (main.ts) gera esta constraint pra
  // qualquer campo não esperado enviado no corpo da requisição.
  whitelistValidation: (campo) => `Campo não reconhecido: ${campo}`,
};

/// Extrai o primeiro número da mensagem original em inglês — cobre
/// `min`/`max` ("must not be less than 1") e `minLength`/`maxLength`
/// ("must be longer than or equal to 2 characters"), os únicos templates
/// acima que precisam de um limite além do nome do campo (`@Min(1)` etc.
/// não expõe esse valor em nenhum outro lugar de `ValidationError`).
function extrairNumero(mensagemOriginal: string): string | undefined {
  return mensagemOriginal.match(/-?\d+(?:\.\d+)?/)?.[0];
}

function traduzirErro(erro: ValidationError, mensagens: string[]): void {
  if (erro.constraints) {
    for (const [tipo, mensagemOriginal] of Object.entries(erro.constraints)) {
      const template = TRADUCOES[tipo];
      mensagens.push(
        template ? template(erro.property, extrairNumero(mensagemOriginal)) : mensagemOriginal,
      );
    }
  }
  for (const filho of erro.children ?? []) {
    traduzirErro(filho, mensagens);
  }
}

/// `exceptionFactory` do `ValidationPipe` global (main.ts). Sem isso, todo
/// decorator do class-validator sem `message:` explícito — a grande
/// maioria dos ~300 usados no projeto — vaza texto em inglês pro usuário
/// final, porque `mensagemErroApi` (frontend, `dio_error_message.dart`)
/// mostra `message` da resposta da API sem nenhuma tradução (docs/30,
/// item "fortemente recomendado": nenhuma mensagem de validação em
/// inglês). Corrigir isso decorator por decorator em ~95 arquivos de DTO
/// seria um trabalho enorme e frágil (qualquer novo DTO futuro reintroduz
/// o problema); centralizar na fábrica de exceção corrige de uma vez e
/// protege automaticamente qualquer DTO novo.
export function exceptionFactoryValidacao(erros: ValidationError[]): BadRequestException {
  const mensagens: string[] = [];
  for (const erro of erros) {
    traduzirErro(erro, mensagens);
  }
  return new BadRequestException(mensagens.length > 0 ? mensagens : ['Dados inválidos']);
}
