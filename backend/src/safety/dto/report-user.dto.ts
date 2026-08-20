import { IsIn, IsEnum, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { ReportReason } from '../../database/enums/report-reason.enum';

export class ReportUserDto {
  @IsEnum(ReportReason)
  reason: ReportReason;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  message?: string;

  // Which mission/service-request this happened on, if either — see
  // UserReport.contextType. Both optional and independent of each other;
  // the controller only actually uses them together.
  @IsOptional()
  @IsIn(['mission', 'service_request'])
  contextType?: 'mission' | 'service_request';

  @IsOptional()
  @IsUUID()
  contextId?: string;
}
