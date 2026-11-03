import {
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class UpdateFcmTokenDto {
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  fcmToken: string;

  // Sent by app builds that can ring for new requests; absent from older ones.
  @IsOptional()
  @IsBoolean()
  ringCapable?: boolean;
}
