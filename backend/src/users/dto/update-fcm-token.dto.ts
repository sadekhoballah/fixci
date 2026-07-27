import { IsString, MaxLength, MinLength } from 'class-validator';

export class UpdateFcmTokenDto {
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  fcmToken: string;
}
