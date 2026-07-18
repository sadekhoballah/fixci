import {
  IsEnum,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  ValidateIf,
} from 'class-validator';
import { UserRole } from '../../database/enums/user-role.enum';
import { ServiceCategory } from '../../database/enums/service-category.enum';

export class RegisterUserDto {
  @Matches(/^\+[1-9]\d{7,14}$/, {
    message: 'phone must be in E.164 format, e.g. +2250700000001',
  })
  phone: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  fullName?: string;

  @IsEnum(UserRole)
  role: UserRole;

  @ValidateIf((dto: RegisterUserDto) => dto.role === UserRole.CRAFTSMAN)
  @IsEnum(ServiceCategory)
  serviceCategory?: ServiceCategory;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  experienceDetails?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  idCardStorageKey?: string;

  @IsOptional()
  @IsString()
  firebaseIdToken?: string;
}
