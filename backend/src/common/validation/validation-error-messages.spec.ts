import {
  IsBoolean,
  IsDateString,
  IsEmail,
  IsEnum,
  IsHexColor,
  IsInt,
  IsNotEmpty,
  IsNotEmptyObject,
  IsNumber,
  IsObject,
  IsPositive,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
  validate,
} from 'class-validator';
import { Type, plainToInstance } from 'class-transformer';
import { exceptionFactoryValidacao } from './validation-error-messages';

enum StatusFake {
  ATIVO = 'ATIVO',
}

class DtoFilho {
  @IsString()
  descricao!: string;
}

class DtoTeste {
  @IsString()
  nome!: string;

  @MinLength(2)
  apelido!: string;

  @MaxLength(2)
  sigla!: string;

  @IsDateString()
  data!: string;

  @IsEnum(StatusFake)
  status!: StatusFake;

  @IsEmail()
  email!: string;

  @IsNumber()
  valorNumerico!: number;

  @IsPositive()
  valorPositivo!: number;

  @IsInt()
  quantidade!: number;

  @Min(5)
  minimo!: number;

  @Max(5)
  maximo!: number;

  @IsUUID()
  identificador!: string;

  @IsBoolean()
  ativo!: boolean;

  @IsHexColor()
  cor!: string;

  @IsObject()
  configuracao!: object;

  @IsNotEmptyObject()
  objetoObrigatorio!: object;

  @IsNotEmpty()
  campoObrigatorio!: string;

  // Custom message já em português — precisa continuar intacto.
  @Matches(/^\d{2}:\d{2}$/, { message: 'horario deve estar no formato HH:mm' })
  horario!: string;

  @ValidateNested()
  @Type(() => DtoFilho)
  filho!: DtoFilho;
}

describe('exceptionFactoryValidacao', () => {
  it('traduz cada tipo de constraint pra uma mensagem em português, sem nenhum texto em inglês', async () => {
    const dto = plainToInstance(DtoTeste, {
      nome: 1,
      apelido: 'a',
      sigla: 'abc',
      data: 'não é data',
      status: 'INEXISTENTE',
      email: 'não é email',
      valorNumerico: 'não é número',
      valorPositivo: -1,
      quantidade: 1.5,
      minimo: 1,
      maximo: 10,
      identificador: 'não é uuid',
      ativo: 'não é boolean',
      cor: 'não é cor',
      configuracao: 'não é objeto',
      objetoObrigatorio: {},
      campoObrigatorio: '',
      horario: '25h',
      filho: { descricao: 123 },
    });

    const erros = await validate(dto);
    const excecao = exceptionFactoryValidacao(erros);
    const mensagens = (excecao.getResponse() as { message: string[] }).message;

    // Nenhuma mensagem deve conter as palavras-chave clássicas do
    // class-validator em inglês (must/should/property/value).
    for (const mensagem of mensagens) {
      expect(mensagem).not.toMatch(/\b(must|should|property|value)\b/i);
    }

    expect(mensagens).toContain('nome deve ser texto');
    expect(mensagens).toContain('apelido deve ter no mínimo 2 caracteres');
    expect(mensagens).toContain('sigla deve ter no máximo 2 caracteres');
    expect(mensagens).toContain('data deve ser uma data válida');
    expect(mensagens).toContain('status tem um valor inválido');
    expect(mensagens).toContain('email deve ser um e-mail válido');
    expect(mensagens).toContain('valorNumerico deve ser um número');
    expect(mensagens).toContain('valorPositivo deve ser maior que zero');
    expect(mensagens).toContain('quantidade deve ser um número inteiro');
    expect(mensagens).toContain('minimo não pode ser menor que 5');
    expect(mensagens).toContain('maximo não pode ser maior que 5');
    expect(mensagens).toContain('identificador é inválido');
    expect(mensagens).toContain('ativo deve ser verdadeiro ou falso');
    expect(mensagens).toContain('cor deve ser uma cor no formato #RRGGBB');
    expect(mensagens).toContain('configuracao deve ser um objeto');
    expect(mensagens).toContain('campoObrigatorio é obrigatório');
    // Mensagem customizada (já em português) preservada sem alteração.
    expect(mensagens).toContain('horario deve estar no formato HH:mm');
    // Erro de um DTO aninhado (`@ValidateNested`) também é traduzido.
    expect(mensagens).toContain('descricao deve ser texto');
  });

  it('sem erros, devolve uma mensagem genérica em português (nunca uma lista vazia silenciosa)', () => {
    const excecao = exceptionFactoryValidacao([]);
    expect((excecao.getResponse() as { message: string[] }).message).toEqual(['Dados inválidos']);
  });
});
