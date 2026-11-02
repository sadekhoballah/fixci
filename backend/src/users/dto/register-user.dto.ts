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

  // Mandatory KYC document for craftsmen only — except for an
  // OTP_TEST_PHONES number (Play Store review / pilot), which may register
  // with no document at all. See ../../auth/otp-test-phones.ts. Clients no
  // longer upload one: the phone OTP is their only verification. Older app
  // builds may still send one for a client; it's stored as before.
  @ValidateIf(
    (dto: RegisterUserDto) =>
      dto.role === UserRole.CRAFTSMAN && !isOtpTestPhone(dto.phone),
  )
  @IsNotEmpty()
  @IsString()
  @MaxLength(255)
  idCardStorageKey?: string;

  // Proof this phone was actually OTP-verified — issued by
  // POST /auth/otp/check when no account exists yet for the phone (see
  // TokensService.issueRegistrationToken). Required for a craftsman. A
  // client registers without it (phoneVerified: false) and confirms the
  // number by OTP once, the first time they request a craftsman / post or
  // apply to a mission — see assertPhoneVerified. Still accepted from a
  // client (older app builds verify up front), in which case the account
  // starts out verified.
  @ValidateIf(
    (dto: RegisterUserDto) =>
      dto.role === UserRole.CRAFTSMAN || dto.registrationToken != null,
  )
  @IsNotEmpty()
  @IsString()
  registrationToken?: string | null;

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
