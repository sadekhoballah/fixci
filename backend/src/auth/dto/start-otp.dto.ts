import { IsIn, IsOptional, Matches } from 'class-validator';

export class StartOtpDto {
  // Same E.164 pattern as RegisterUserDto — keeps "what counts as a valid
  // phone number" consistent across both entry points.
  @Matches(/^\+[1-9]\d{7,14}$/, {
    message: 'phone must be in E.164 format, e.g. +2250700000001',
  })
  phone: string;

  // Omitted on the first request (defaults to WhatsApp, the primary
  // channel); the client sends 'sms' only when the user taps the explicit
  // "receive by SMS" fallback on the OTP screen.
  @IsOptional()
  @IsIn(['whatsapp', 'sms'])
  channel?: 'whatsapp' | 'sms';
}
