import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsLatitude,
  IsLongitude,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { ServiceCategory } from '../../database/enums/service-category.enum';

export class CreateMissionDto {
  @IsNotEmpty()
  @IsString()
  @MaxLength(150)
  title: string;

  @IsNotEmpty()
  @IsString()
  @MaxLength(2000)
  description: string;

  // Browse/filter tag only — never fed into the real-time matching engine.
  // Optional: a mission doesn't have to fit a fixed trade.
  @IsOptional()
  @IsEnum(ServiceCategory)
  category?: ServiceCategory;

  @IsNotEmpty()
  @IsString()
  @MaxLength(500)
  locationAddress: string;

  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;

  // Storage keys returned by POST /uploads/mission-photo, uploaded
  // individually beforehand — see UploadsController.
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(3)
  @IsString({ each: true })
  @MaxLength(255, { each: true })
  photoStorageKeys?: string[];
}
