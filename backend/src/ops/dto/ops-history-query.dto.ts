import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { ServiceRequestStatus } from '../../database/enums/service-request-status.enum';

// Terminal states of a Missions/Freelance board post: COMPLETED (done by the
// selected applicant), ARCHIVED (poster withdrew it — the board has no
// separate "cancelled" status, see MissionStatus) and REJECTED (refused at
// moderation).
export const MISSION_HISTORY_STATUSES = [
  'completed',
  'archived',
  'rejected',
] as const;
export type MissionHistoryStatus = (typeof MISSION_HISTORY_STATUSES)[number];

class PagedQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number;

  // A single UTC calendar day (Abidjan is UTC+0), YYYY-MM-DD.
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'date must be YYYY-MM-DD' })
  date?: string;
}

export class MissionHistoryQueryDto extends PagedQueryDto {
  @IsOptional()
  @IsIn(MISSION_HISTORY_STATUSES)
  status?: MissionHistoryStatus;

  // Matches the title, or the poster's / performer's name or phone.
  @IsOptional()
  @IsString()
  @MaxLength(100)
  search?: string;
}

export class RequestHistoryQueryDto extends PagedQueryDto {
  @IsOptional()
  @IsIn(Object.values(ServiceRequestStatus))
  status?: ServiceRequestStatus;

  // Name or phone of the client who made the request.
  @IsOptional()
  @IsString()
  @MaxLength(100)
  client?: string;

  // Name or phone of the craftsman assigned to it.
  @IsOptional()
  @IsString()
  @MaxLength(100)
  artisan?: string;
}
