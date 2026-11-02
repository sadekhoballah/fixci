import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { RegisterUserDto } from './register-user.dto';

const base = {
  phone: '+2250700000020',
  fullName: 'Aya Kone',
  districtId: '7f1c2a4e-1b2c-4d5e-8f90-123456789abc',
};

async function errorFields(payload: object): Promise<string[]> {
  const errors = await validate(plainToInstance(RegisterUserDto, payload));
  return errors.map((error) => error.property);
}

describe('RegisterUserDto', () => {
  it('accepts a client with no ID document and no registration token', async () => {
    expect(await errorFields({ ...base, role: 'client' })).toEqual([]);
    expect(
      await errorFields({ ...base, role: 'client', registrationToken: null }),
    ).toEqual([]);
  });

  it('still requires the ID document and the OTP token for a craftsman', async () => {
    const fields = await errorFields({
      ...base,
      role: 'craftsman',
      serviceCategory: 'plumber',
      experienceDetails: '1-2 ans',
    });
    expect(fields).toContain('idCardStorageKey');
    expect(fields).toContain('registrationToken');
  });
});
