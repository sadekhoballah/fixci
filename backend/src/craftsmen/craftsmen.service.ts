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

@Injectable()
export class CraftsmenService {
  constructor(
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
    private readonly presenceService: PresenceService,
    private readonly dataSource: DataSource,
  ) {}

  async getMe(phone: string): Promise<CraftsmanMe> {
    const profile = await this.findCraftsmanProfileByPhone(phone);
    return {
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
    dto: SetAvailabilityDto,
  ): Promise<{ isAvailable: boolean }> {
    const profile = await this.findCraftsmanProfileByPhone(dto.phone);

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

  async getStats(phone: string): Promise<CraftsmanStats> {
    const profile = await this.findCraftsmanProfileByPhone(phone);

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

  private async findCraftsmanProfileByPhone(
    phone: string,
  ): Promise<CraftsmanProfile> {
    const user = await this.userRepository.findOne({ where: { phone } });
    if (!user || user.role !== UserRole.CRAFTSMAN) {
      throw new NotFoundException(
        'No craftsman account with this phone number',
      );
    }
    const profile = await this.craftsmanProfileRepository.findOne({
      where: { userId: user.id },
    });
    if (!profile) {
      throw new NotFoundException('No craftsman profile for this account');
    }
    return profile;
  }

  private daysRemaining(expiresAt: Date | null): number | null {
    if (!expiresAt) return null;
    const diffMs = expiresAt.getTime() - Date.now();
    return Math.max(0, Math.ceil(diffMs / MS_PER_DAY));
  }
}
