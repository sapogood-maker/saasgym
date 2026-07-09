import { validate } from 'class-validator';
import { IsCPF, isValidCPF } from './is-cpf.decorator';

describe('isValidCPF', () => {
  it.each(['11144477735', '52998224725'])('aceita um CPF real e válido (%s)', (cpf) => {
    expect(isValidCPF(cpf)).toBe(true);
  });

  it('aceita CPF com pontuação/traço, desde que o dígito verificador esteja correto', () => {
    // isValidCPF em si espera só dígitos — a máscara é removida no decorator,
    // não aqui. Este teste documenta esse contrato.
    expect(isValidCPF('111.444.777-35'.replace(/\D/g, ''))).toBe(true);
  });

  it('rejeita dígito verificador incorreto', () => {
    expect(isValidCPF('11144477736')).toBe(false);
  });

  it.each(['00000000000', '11111111111', '99999999999'])(
    'rejeita sequências de dígitos repetidos, mesmo passando na conta (%s)',
    (cpf) => {
      expect(isValidCPF(cpf)).toBe(false);
    },
  );

  it('rejeita tamanho errado', () => {
    expect(isValidCPF('123456789')).toBe(false);
    expect(isValidCPF('111444777350')).toBe(false);
  });

  it('rejeita valor não numérico', () => {
    expect(isValidCPF('abc.def.ghi-jk')).toBe(false);
  });
});

describe('@IsCPF() (integração com class-validator)', () => {
  class Dto {
    @IsCPF()
    cpf!: string;
  }

  it('aceita um CPF válido formatado com pontuação', async () => {
    const dto = new Dto();
    dto.cpf = '111.444.777-35';

    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
  });

  it('rejeita um CPF inválido com a mensagem correta', async () => {
    const dto = new Dto();
    dto.cpf = '111.444.777-36';

    const errors = await validate(dto);
    expect(errors).toHaveLength(1);
    expect(errors[0].constraints).toMatchObject({ isCPF: 'CPF inválido' });
  });

  it('rejeita valor não-string', async () => {
    const dto = new Dto();
    // @ts-expect-error propositalmente um valor do tipo errado
    dto.cpf = 11144477735;

    const errors = await validate(dto);
    expect(errors).toHaveLength(1);
  });
});
