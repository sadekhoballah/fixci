import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { UserRole } from '../database/enums/user-role.enum';
import { SubscriptionTier } from '../database/enums/subscription-tier.enum';
import { PresenceService } from '../matching/presence.service';
import { SetAvailabilityDto } from './dto/set-availability.dto';

const MS_PER_DAY = 24 * 60 * 60 * 1000;

export interface CraftsmanMe {
  fullName: string | null;
  subscriptionTier: SubscriptionTier;
  subscriptionExpiresAt: Date | null;
  daysRemaining: number | null;
  isAvailable: boolean;
  averageRating: number | null;
  ratingsCount: number;
  serviceCategory: string;
}

export interface CraftsmanStats {
  jobsDoneToday: number;
  jobsAssignedToday: number;
  avgResponseSeconds: number | null;
}

export interface ActiveJob {
  requestId: string;
  serviceCategory: string;
  status: 'assigned' | 'in_progress';
  clientFullName: string | null;
  clientPhone: string;
  clientLatitude: number;
  clientLongitude: number;
  assignedAt: Date;
  startedAt: Date | null;
}

export interface JobHistoryItem {
  requestId: string;
  serviceCategory: string;
  status: string;
  clientFullName: string | null;
  createdAt: Date;
  assignedAt: Date | null;
  startedAt: Date | null;
  completedAt: Date | null;
  cancelledAt: Date | null;
  ratingStars: number | null;
  ratingComment: string | null;
}

interface ActiveJobRow {
  id: string;
  service_category: string;
  status: 'assigned' | 'in_progress';
  client_full_name: string | null;
  client_phone: string;
  latitude: string;
  longitude: string;
  assigned_at: Date;
  started_at: Date | null;
}

interface JobHistoryRow {
  id: string;
  service_category: string;
  status: string;
  client_full_name: string | null;
  created_at: Date;
  assigned_at: Date | null;
  started_at: Date | null;
  completed_at: Date | null;
  cancelled_at: Date | null;
  rating_stars: number | null;
  rating_comment: string | null;
}

@Injectable()
export class CraftsmenService {
  constructor(
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
    private readonly presenceService: PresenceService,
    private readonly dataSource: DataSource,
  ) {}

  async getMe(userId: string): Promise<CraftsmanMe> {
    const { user, profile } = await this.findCraftsmanByUserId(userId);
    return {
      fullName: user.fullName,
      subscriptionTier: profile.subscriptionTier,
      subscriptionExpiresAt: profile.subscriptionExpiresAt,
      daysRemaining: this.daysRemaining(profile.subscriptionExpiresAt),
      isAvailable: profile.isAvailable,
      averageRating:
        profile.averageRating === null ? null : Number(profile.averageRating),
      ratingsCount: profile.ratingsCount,
      serviceCategory: profile.serviceCategory,
    };
  }

  async setAvailability(
    userId: string,
    dto: SetAvailabilityDto,
  ): Promise<{ isAvailable: boolean }> {
    const { profile } = await this.findCraftsmanByUserId(userId);

    if (dto.available) {
      await this.presenceService.setOnline(
        profile.userId,
        profile.serviceCategory,
        dto.longitude!,
        dto.latitude!,
      );
    } else {
      await this.presenceService.setOffline(profile.userId);
    }

    await this.craftsmanProfileRepository.update(
      { userId: profile.userId },
      { isAvailable: dto.available },
    );

    return { isAvailable: dto.available };
  }

  async getStats(userId: string): Promise<CraftsmanStats> {
    const { profile } = await this.findCraftsmanByUserId(userId);

    const [{ count: jobsDoneToday }]: [{ count: string }] =
      await this.dataSource.query(
        `SELECT count(*) FROM "service_requests"
         WHERE "craftsman_id" = $1 AND "status" = 'completed'
           AND "completed_at" >= date_trunc('day', now())`,
        [profile.userId],
      );

    const [{ count: jobsAssignedToday }]: [{ count: string }] =
      await this.dataSource.query(
        `SELECT count(*) FROM "service_requests"
         WHERE "craftsman_id" = $1
           AND "assigned_at" >= date_trunc('day', now())`,
        [profile.userId],
      );

    const [{ avg_seconds: avgSeconds }]: [{ avg_seconds: string | null }] =
      await this.dataSource.query(
        `SELECT avg(extract(epoch from ("assigned_at" - "created_at"))) AS avg_seconds
         FROM "service_requests"
         WHERE "craftsman_id" = $1 AND "assigned_at" IS NOT NULL`,
        [profile.userId],
      );

    return {
      jobsDoneToday: Number(jobsDoneToday),
      jobsAssignedToday: Number(jobsAssignedToday),
      avgResponseSeconds: avgSeconds === null ? null : Number(avgSeconds),
    };
  }

  // The job the craftsman is currently working (assigned or in_progress),
  // if any — lets the app restore "you have an active job" state on cold
  // start, without relying on client-held state surviving an app restart.
  async getActiveJob(userId: string): Promise<ActiveJob | null> {
    await this.findCraftsmanByUserId(userId);

    const rows: ActiveJobRow[] = await this.dataSource.query(
      `SELECT sr."id", sr."service_category", sr."status",
              sr."assigned_at", sr."started_at",
              u."full_name" AS client_full_name, u."phone" AS client_phone,
              ST_Y(sr."client_location"::geometry) AS latitude,
              ST_X(sr."client_location"::geometry) AS longitude
       FROM "service_requests" sr
       JOIN "users" u ON u."id" = sr."client_id"
       WHERE sr."craftsman_id" = $1 AND sr."status" IN ('assigned', 'in_progress')
       ORDER BY sr."assigned_at" DESC
       LIMIT 1`,
      [userId],
    );
    if (rows.length === 0) return null;

    const row = rows[0];
    return {
      requestId: row.id,
      serviceCategory: row.service_category,
      status: row.status,
      clientFullName: row.client_full_name,
      clientPhone: row.client_phone,
      clientLatitude: Number(row.latitude),
      clientLongitude: Number(row.longitude),
      assignedAt: row.assigned_at,
      startedAt: row.started_at,
    };
  }

  // Every job this craftsman was ever assigned, past or present — this is
  // what backs the History tab. Requests that never left `pending` have no
  // craftsman_id yet, so they're excluded by the WHERE clause naturally.
  async getJobHistory(
    userId: string,
    limit: number,
    offset: number,
  ): Promise<JobHistoryItem[]> {
    await this.findCraftsmanByUserId(userId);

    const rows: JobHistoryRow[] = await this.dataSource.query(
      `SELECT sr."id", sr."service_category", sr."status", sr."created_at",
              sr."assigned_at", sr."started_at", sr."completed_at", sr."cancelled_at",
              u."full_name" AS client_full_name,
              r."stars" AS rating_stars, r."comment" AS rating_comment
       FROM "service_requests" sr
       JOIN "users" u ON u."id" = sr."client_id"
       LEFT JOIN "ratings" r ON r."service_request_id" = sr."id"
       WHERE sr."craftsman_id" = $1
       ORDER BY sr."created_at" DESC
       LIMIT $2 OFFSET $3`,
      [userId, limit, offset],
    );

    return rows.map((row) => ({
      requestId: row.id,
      serviceCategory: row.service_category,
      status: row.status,
      clientFullName: row.client_full_name,
      createdAt: row.created_at,
      assignedAt: row.assigned_at,
      startedAt: row.started_at,
      completedAt: row.completed_at,
      cancelledAt: row.cancelled_at,
      ratingStars: row.rating_stars === null ? null : Number(row.rating_stars),
      ratingComment: row.rating_comment,
    }));
  }

  private async findCraftsmanByUserId(
    userId: string,
  ): Promise<{ user: User; profile: CraftsmanProfile }> {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user || user.role !== UserRole.CRAFTSMAN) {
      throw new NotFoundException('No craftsman account for this user');
    }
    const profile = await this.craftsmanProfileRepository.findOne({
      where: { userId: user.id },
    });
    if (!profile) {
      throw new NotFoundException('No craftsman profile for this account');
    }
    return { user, profile };
  }

  private daysRemaining(expiresAt: Date | null): number | null {
    if (!expiresAt) return null;
    const diffMs = expiresAt.getTime() - Date.now();
    return Math.max(0, Math.ceil(diffMs / MS_PER_DAY));
  }
}
