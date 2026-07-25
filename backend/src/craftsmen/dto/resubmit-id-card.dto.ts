import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class ResubmitIdCardDto {
  @IsNotEmpty()
  @IsString()
  @MaxLength(255)
  idCardStorageKey: string;
}
