import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

// 'dismiss' — no action, just clears the queue (e.g. unfounded report).
// 'warn' — noted, but the account stays active (mirrors a verbal warning;
// nothing actually changes account-side, this is purely the admin's own
// record via adminNote on the report row).
// 'deactivate_reported' — reuses AdminService's existing
// deactivateCraftsman/deactivateClient dispatch, same isActive flip as a
// KYC rejection.
export class ResolveReportDto {
  @IsIn(['dismiss', 'warn', 'deactivate_reported'])
  action: 'dismiss' | 'warn' | 'deactivate_reported';

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
