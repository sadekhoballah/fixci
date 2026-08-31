import {
  IsEnum,
  IsNotEmpty,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  ValidateIf,
} from 'class-validator';
import { UserRole } from '../../database/enums/user-role.enum';
import { ServiceCategory } from '../../database/enums/service-category.enum';
import { isOtpTestPhone } from '../../auth/otp-test-phones';

export class RegisterUserDto {
  @Matches(/^\+[1-9]\d{7,14}$/, {
    message: 'phone must be in E.164 format, e.g. +2250700000001',
  })
  phone: string;

  @IsNotEmpty()
  @IsString()
  @MaxLength(120)
  fullName: string;

  @IsEnum(UserRole)
  role: UserRole;

  // Picked manually at registration, both roles — see District entity.
  @IsUUID()
  districtId: string;

  @ValidateIf((dto: RegisterUserDto) => dto.role === UserRole.CRAFTSMAN)
  @IsEnum(ServiceCategory)
  serviceCategory?: ServiceCategory;

  @ValidateIf((dto: RegisterUserDto) => dto.role === UserRole.CRAFTSMAN)
  @IsNotEmpty()
  @IsString()
  @MaxLength(2000)
  experienceDetails?: string;

  // Mandatory KYC document for both roles — except for an OTP_TEST_PHONES
  // number (Play Store review / pilot), which may register with no document
  // at all. See ../../auth/otp-test-phones.ts.
  @ValidateIf((dto: RegisterUserDto) => !isOtpTestPhone(dto.phone))
  @IsNotEmpty()
  @IsString()
  @MaxLength(255)
  idCardStorageKey?: string;

  // Proof this phone was actually OTP-verified — issued by
  // POST /auth/otp/check when no account exists yet for the phone (see
  // TokensService.issueRegistrationToken). Required: registration can no
  // longer happen without having verified the phone first.
  @IsNotEmpty()
  @IsString()
  registrationToken: string;

  // Second mandatory document, taxi/camion craftsmen only — see
  // CraftsmanProfile.licenseStorageKey.
  @ValidateIf(
    (dto: RegisterUserDto) =>
      !isOtpTestPhone(dto.phone) &&
      dto.role === UserRole.CRAFTSMAN &&
      (dto.serviceCategory === ServiceCategory.TAXI ||
        dto.serviceCategory === ServiceCategory.CAMION),
  )
  @IsNotEmpty()
  @IsString()
  @MaxLength(255)
  licenseStorageKey?: string;
}
