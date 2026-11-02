import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Brackets, DataSource, Repository } from 'typeorm';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { UserRole } from '../database/enums/user-role.enum';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { PresenceService } from '../matching/presence.service';

export interface DirectoryEntry {
  userId: string;
  fullName: string | null;
  phone: string | null;
  districtName: string;
  countryCode: string;
  isOnline: boolean;
  // Clients now sign up without a code and confirm their number once, at
  // their first request (see assertPhoneVerified) — false until then.
  phoneVerified: boolean;
}

export interface CraftsmanDirectoryEntry extends DirectoryEntry {
  serviceCategory: ServiceCategory;
  // Null/0 until the craftsman's first rating — mirrors
  // CraftsmanProfile.averageRating/ratingsCount, kept in sync by
  // MatchingService.submitRating on every new rating.
  averageRating: number | null;
  ratingsCount: number;
  completedCount: number;
  // Every request that ever reached 'assigned' with this craftsman,
  // regardless of what happened after (completed, cancelled post-assignment,
  // etc.) — how often they get matched, not just how often they finish.
  assignedCount: number;
  idVerified: boolean;
  isActive: boolean;
}

@Injectable()
export class DirectoryService {
  constructor(
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
    private readonly presenceService: PresenceService,
    private readonly dataSource: DataSource,
  ) {}

  // search matches the phone or the name.
  async listClients(
    search?: string,
    country?: string,
  ): Promise<DirectoryEntry[]> {
    const onlineIds = new Set(await this.presenceService.listOnlineClientIds());
    const qb = this.userRepository
      .createQueryBuilder('user')
      .innerJoinAndSelect('user.district', 'district')
      .where('user.role = :role', { role: UserRole.CLIENT })
      .andWhere('user.deletedAt IS NULL')
      .orderBy('user.fullName', 'ASC');
    this.applySearchAndCountry(qb, search, country);
    const users = await qb.getMany();
    return users.map((user) => ({
      userId: user.id,
      fullName: user.fullName,
      phone: user.phone,
      districtName: user.district.name,
      countryCode: user.district.countryCode,
      isOnline: onlineIds.has(user.id),
      phoneVerified: user.phoneVerified,
    }));
  }

  async listCraftsmen(
    search?: string,
    category?: ServiceCategory,
    country?: string,
  ): Promise<CraftsmanDirectoryEntry[]> {
    // "Online" here reuses the same Redis presence PresenceService.listOnline
    // already exposes for the Live Ops roster (module 4) — a craftsman is
    // online when they've explicitly gone available, not just connected.
    const online = await this.presenceService.listOnline();
    const onlineIds = new Set(online.map((entry) => entry.craftsmanId));

    const qb = this.craftsmanProfileRepository
      .createQueryBuilder('cp')
      .innerJoinAndSelect('cp.user', 'user')
      .innerJoinAndSelect('user.district', 'district')
      .where('user.deletedAt IS NULL')
      .orderBy('user.fullName', 'ASC');
    this.applySearchAndCountry(qb, search, country);
    if (category) {
      qb.andWhere('cp.serviceCategory = :category', { category });
    }
    const profiles = await qb.getMany();
    const missionCounts = await this.aggregateMissionCounts(
      profiles.map((profile) => profile.userId),
    );

    return profiles.map((profile) => {
      const counts = missionCounts.get(profile.userId);
      return {
        userId: profile.userId,
        fullName: profile.user.fullName,
        phone: profile.user.phone,
        districtName: profile.user.district.name,
        countryCode: profile.user.district.countryCode,
        serviceCategory: profile.serviceCategory,
        isOnline: onlineIds.has(profile.userId),
        phoneVerified: profile.user.phoneVerified,
        idVerified: profile.idVerified,
        isActive: profile.isActive,
        averageRating:
          profile.averageRating === null ? null : Number(profile.averageRating),
        ratingsCount: profile.ratingsCount,
        completedCount: counts?.completedCount ?? 0,
        assignedCount: counts?.assignedCount ?? 0,
      };
    });
  }

  private applySearchAndCountry(
    qb: {
      andWhere: (condition: Brackets | string, params?: object) => unknown;
    },
    search?: string,
    country?: string,
  ): void {
    const term = search?.trim();
    if (term) {
      const pattern = `%${term.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
      qb.andWhere(
        new Brackets((sub) => {
          sub
            .where('user.phone ILIKE :search', { search: pattern })
            .orWhere('user.fullName ILIKE :search', { search: pattern });
        }),
      );
    }
    if (country) {
      qb.andWhere('district.countryCode = :country', { country });
    }
  }

  // One grouped query for every craftsman in the current page rather than
  // one COUNT per row — completedCount/assignedCount aren't denormalized
  // onto CraftsmanProfile the way averageRating/ratingsCount are, so this
  // reads straight from service_requests.
  private async aggregateMissionCounts(
    craftsmanIds: string[],
  ): Promise<Map<string, { completedCount: number; assignedCount: number }>> {
    if (craftsmanIds.length === 0) return new Map();
    const rows: Array<{
      craftsman_id: string;
      completed_count: string;
      assigned_count: string;
    }> = await this.dataSource.query(
      `SELECT "craftsman_id",
              count(*) FILTER (WHERE "status" = 'completed') AS completed_count,
              count(*) FILTER (WHERE "assigned_at" IS NOT NULL) AS assigned_count
       FROM "service_requests"
       WHERE "craftsman_id" = ANY($1)
       GROUP BY "craftsman_id"`,
      [craftsmanIds],
    );
    return new Map(
      rows.map((row) => [
        row.craftsman_id,
        {
          completedCount: Number(row.completed_count),
          assignedCount: Number(row.assigned_count),
        },
      ]),
    );
  }
}
