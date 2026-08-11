import { Matches } from 'class-validator';

export class SendOtpDto {
  // Same E.164 pattern as RegisterUserDto — keeps "what counts as a valid
  // phone number" consistent across both entry points.
  @Matches(/^\+[1-9]\d{7,14}$/, {
    message: 'phone must be in E.164 format, e.g. +2250700000001',
  })
  phone: string;
}
