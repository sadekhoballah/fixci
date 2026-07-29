import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { User } from '../database/entities/user.entity';
import { ServiceRequest } from '../database/entities/service-request.entity';
import { ServiceRequestStatus } from '../database/enums/service-request-status.enum';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { PresenceService } from '../matching/presence.service';

export interface OnlineCraftsmanRow {
  craftsmanId: string;
  fullName: string | null;
  phone: string;
  category: ServiceCategory;
  districtName: string;
  onlineSince: Date | null;
}

export type OpsStatsRange = 'today' | 'week' | 'all';

export interface OpsStats {
  range: OpsStatsRange;
  byStatus: { status: ServiceRequestStatus; count: number }[];
  byDistrict: { districtId: string; districtName: string; count: number }[];
  byCategory: { category: ServiceCategory; count: number }[];
}

@Injectable()
export class OpsService {
  constructor(
    private readonly presenceService: PresenceService,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(ServiceRequest)
    private readonly serviceRequestRepository: Repository<ServiceRequest>,
  ) {}

  async getPresence(): Promise<OnlineCraftsmanRow[]> {
    const online = await this.presenceService.listOnline();
    if (online.length === 0) return [];

    const users = await this.userRepository.find({
      where: { id: In(online.map((o) => o.craftsmanId)) },
      relations: { district: true },
    });
    const userById = new Map(users.map((u) => [u.id, u]));

    // A stale Redis entry (account deleted after going online) has no
    // matching user row — drop it rather than surfacing a broken row.
    return online
      .map((entry) => {
        const user = userById.get(entry.craftsmanId);
        if (!user) return null;
        return {
          craftsmanId: entry.craftsmanId,
          fullName: user.fullName,
          phone: user.phone,
          category: entry.category,
          districtName: user.district.name,
          onlineSince: entry.onlineSince,
        };
      })
      .filter((row): row is OnlineCraftsmanRow => row !== null)
      .sort((a, b) => (b.onlineSince?.getTime() ?? 0) - (a.onlineSince?.getTime() ?? 0));
  }

  async getStats(range: OpsStatsRange): Promise<OpsStats> {
    const since = this.rangeStart(range);

    const [statusRows, districtRows, categoryRows] = await Promise.all([
      this.serviceRequestRepository
        .createQueryBuilder('sr')
        .select('sr.status', 'status')
        .addSelect('COUNT(*)', 'count')
        .where(since ? 'sr.createdAt >= :since' : '1=1', { since })
        .groupBy('sr.status')
        .getRawMany<{ status: ServiceRequestStatus; count: string }>(),
      this.serviceRequestRepository
        .createQueryBuilder('sr')
        .innerJoin('sr.client', 'client')
        .innerJoin('client.district', 'district')
        .select('district.id', 'districtId')
        .addSelect('district.name', 'districtName')
        .addSelect('COUNT(*)', 'count')
        .where(since ? 'sr.createdAt >= :since' : '1=1', { since })
        .groupBy('district.id')
        .addGroupBy('district.name')
        .orderBy('count', 'DESC')
        .getRawMany<{ districtId: string; districtName: string; count: string }>(),
      this.serviceRequestRepository
        .createQueryBuilder('sr')
        .select('sr.serviceCategory', 'category')
        .addSelect('COUNT(*)', 'count')
        .where(since ? 'sr.createdAt >= :since' : '1=1', { since })
        .groupBy('sr.serviceCategory')
        .orderBy('count', 'DESC')
        .getRawMany<{ category: ServiceCategory; count: string }>(),
    ]);

    const countByStatus = new Map(statusRows.map((r) => [r.status, Number(r.count)]));

    return {
      range,
      byStatus: Object.values(ServiceRequestStatus).map((status) => ({
        status,
        count: countByStatus.get(status) ?? 0,
      })),
      byDistrict: districtRows.map((r) => ({
        districtId: r.districtId,
        districtName: r.districtName,
        count: Number(r.count),
      })),
      byCategory: categoryRows.map((r) => ({
        category: r.category,
        count: Number(r.count),
      })),
    };
  }

  private rangeStart(range: OpsStatsRange): Date | null {
    const now = new Date();
    if (range === 'today') {
      return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    }
    if (range === 'week') {
      return new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    }
    return null;
  }
}
