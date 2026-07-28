import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class CreateDistrictDto {
  @IsNotEmpty()
  @IsString()
  @MaxLength(120)
  name: string;
}
