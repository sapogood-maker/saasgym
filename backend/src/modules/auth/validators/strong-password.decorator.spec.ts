import { validate } from 'class-validator';
import { IsStrongPassword } from './strong-password.decorator';

class TestDto {
  @IsStrongPassword()
  password!: string;
}

async function isValid(password: string): Promise<boolean> {
  const dto = new TestDto();
  dto.password = password;
  const errors = await validate(dto);
  return errors.length === 0;
}

describe('IsStrongPassword', () => {
  it.each(['Senha123', 'Abcdefg1', 'Sup3rSegura!'])('aceita "%s"', async (password) => {
    expect(await isValid(password)).toBe(true);
  });

  it.each([
    ['curta1A', 'menos de 8 caracteres'],
    ['semmaiuscula1', 'sem letra maiúscula'],
    ['SEMMINUSCULA1', 'sem letra minúscula'],
    ['SemNumeroAqui', 'sem número'],
  ])('rejeita "%s" (%s)', async (password) => {
    expect(await isValid(password)).toBe(false);
  });
});
