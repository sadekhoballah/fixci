import { Matches } from 'class-validator';

export class CheckOtpDto {
  @Matches(/^\+[1-9]\d{7,14}$/, {
    message: 'phone must be in E.164 format, e.g. +2250700000001',
  })
  phone: string;

  @Matches(/^\d{6}$/, { message: 'code must be a 6-digit number' })
  code: string;
}
