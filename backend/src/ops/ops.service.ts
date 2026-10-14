import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, Repository } from 'typeorm';
import { User } from '../database/entities/user.entity';
import { ServiceRequest } from '../database/entities/service-request.entity';
import { ServiceRequestStatus } from '../database/enums/service-request-status.enum';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { PresenceService } from '../matching/presence.service';
import {
  MISSION_HISTORY_STATUSES,
  MissionHistoryQueryDto,
  MissionHistoryStatus,
  RequestHistoryQueryDto,
} from './dto/ops-history-query.dto';

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

export interface HistoryUser {
  id: string;
  fullName: string | null;
  phone: string | null;
  // Self-deleted accounts keep their row but have name/phone wiped.
  deleted: boolean;
}

export interface MissionHistoryRow {
  id: string;
  title: string;
  category: ServiceCategory | null;
  status: MissionHistoryStatus;
  locationAddress: string;
  startingPrice: string | null;
  rejectionReason: string | null;
  poster: HistoryUser & { role: string };
  // The applicant the poster selected — null when the mission never got
  // that far (withdrawn / rejected before any selection).
  performer: HistoryUser | null;
  applicationsCount: number;
  createdAt: Date;
  publishedAt: Date | null;
  selectedAt: Date | null;
  completedAt: Date | null;
  archivedAt: Date | null;
  // When it reached its terminal state. REJECTED has no dedicated
  // timestamp, so updated_at stands in for it.
  endedAt: Date;
}

export interface RequestHistoryRow {
  id: string;
  category: ServiceCategory;
  status: ServiceRequestStatus;
  client: HistoryUser;
  craftsman: HistoryUser | null;
  createdAt: Date;
  assignedAt: Date | null;
  startedAt: Date | null;
  completedAt: Date | null;
  cancelledAt: Date | null;
  // Terminal timestamp: completed_at / cancelled_at, or updated_at for
  // EXPIRED (no dedicated column). Null while the request is still open.
  endedAt: Date | null;
  ratingStars: number | null;
}

export interface HistoryPage<T, S extends string> {
  items: T[];
  total: number;
  // Counts per status under the same filters minus the status one, so the
  // UI can show the breakdown of whatever the admin is looking at.
  byStatus: { status: S; count: number }[];
}

// Raw snake_case rows as returned by the history queries below.
interface MissionHistoryDbRow {
  id: string;
  title: string;
  category: ServiceCategory | null;
  status: MissionHistoryStatus;
  location_address: string;
  starting_price: string | null;
  rejection_reason: string | null;
  created_at: Date;
  published_at: Date | null;
  selected_at: Date | null;
  completed_at: Date | null;
  archived_at: Date | null;
  ended_at: Date;
  poster_id: string;
  poster_name: string | null;
  poster_phone: string | null;
  poster_role: string;
  poster_deleted: boolean;
  performer_id: string | null;
  performer_name: string | null;
  performer_phone: string | null;
  performer_deleted: boolean | null;
  applications_count: number;
}

interface RequestHistoryDbRow {
  id: string;
  category: ServiceCategory;
  status: ServiceRequestStatus;
  created_at: Date;
  assigned_at: Date | null;
  started_at: Date | null;
  completed_at: Date | null;
  cancelled_at: Date | null;
  ended_at: Date | null;
  client_id: string;
  client_name: string | null;
  client_phone: string | null;
  client_deleted: boolean;
  craftsman_id: string | null;
  craftsman_name: string | null;
  craftsman_phone: string | null;
  craftsman_deleted: boolean | null;
  rating_stars: number | null;
}

// Escapes ILIKE wildcards so a search for "50%" matches literally.
const likePattern = (term: string) =>
  `%${term.trim().replace(/[\\%_]/g, (c) => `\\${c}`)}%`;

@Injectable()
export class OpsService {
  constructor(
    private readonly presenceService: PresenceService,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(ServiceRequest)
    private readonly serviceRequestRepository: Repository<ServiceRequest>,
    private readonly dataSource: DataSource,
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
      .sort(
        (a, b) =>
          (b.onlineSince?.getTime() ?? 0) - (a.onlineSince?.getTime() ?? 0),
      );
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
        .getRawMany<{
          districtId: string;
          districtName: string;
          count: string;
        }>(),
      this.serviceRequestRepository
        .createQueryBuilder('sr')
        .select('sr.serviceCategory', 'category')
        .addSelect('COUNT(*)', 'count')
        .where(since ? 'sr.createdAt >= :since' : '1=1', { since })
        .groupBy('sr.serviceCategory')
        .orderBy('count', 'DESC')
        .getRawMany<{ category: ServiceCategory; count: string }>(),
    ]);

    const countByStatus = new Map(
      statusRows.map((r) => [r.status, Number(r.count)]),
    );

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

  // Read-only history of Missions/Freelance board posts that reached a
  // terminal state: who posted it, who did it, and when each step happened.
  async getMissionHistory(
    query: MissionHistoryQueryDto,
  ): Promise<HistoryPage<MissionHistoryRow, MissionHistoryStatus>> {
    const conditions = ['m.status::text = ANY($1)'];
    const params: unknown[] = [[...MISSION_HISTORY_STATUSES]];
    if (query.date) {
      params.push(query.date);
      conditions.push(
        `(m.created_at AT TIME ZONE 'UTC')::date = $${params.length}::date`,
      );
    }
    if (query.search?.trim()) {
      params.push(likePattern(query.search));
      const n = params.length;
      conditions.push(
        `(m.title ILIKE $${n} OR p.full_name ILIKE $${n} OR p.phone ILIKE $${n}
          OR a.full_name ILIKE $${n} OR a.phone ILIKE $${n})`,
      );
    }
    const from = `
      FROM missions m
      JOIN users p ON p.id = m.poster_id
      LEFT JOIN mission_applications sel ON sel.id = m.selected_application_id
      LEFT JOIN users a ON a.id = sel.applicant_id`;

    const statusRows: Array<{ status: MissionHistoryStatus; count: number }> =
      await this.dataSource.query(
        `SELECT m.status::text AS status, COUNT(*)::int AS count ${from}
         WHERE ${conditions.join(' AND ')}
         GROUP BY m.status`,
        params,
      );

    const listConditions = [...conditions];
    const listParams = [...params];
    if (query.status) {
      listParams.push(query.status);
      listConditions.push(`m.status::text = $${listParams.length}`);
    }
    listParams.push(query.limit ?? 50, query.offset ?? 0);
    const rows: MissionHistoryDbRow[] = await this.dataSource.query(
      `SELECT
         m.id, m.title, m.category, m.status::text AS status,
         m.location_address, m.starting_price, m.rejection_reason,
         m.created_at, m.published_at, m.selected_at, m.completed_at,
         m.archived_at,
         COALESCE(m.completed_at, m.archived_at, m.updated_at) AS ended_at,
         p.id AS poster_id, p.full_name AS poster_name, p.phone AS poster_phone,
         p.role::text AS poster_role, p.deleted_at IS NOT NULL AS poster_deleted,
         a.id AS performer_id, a.full_name AS performer_name,
         a.phone AS performer_phone,
         a.deleted_at IS NOT NULL AS performer_deleted,
         (SELECT COUNT(*)::int FROM mission_applications ma
           WHERE ma.mission_id = m.id) AS applications_count
       ${from}
       WHERE ${listConditions.join(' AND ')}
       ORDER BY ended_at DESC, m.id
       LIMIT $${listParams.length - 1} OFFSET $${listParams.length}`,
      listParams,
    );

    const countByStatus = new Map(statusRows.map((r) => [r.status, r.count]));
    return {
      total: query.status
        ? (countByStatus.get(query.status) ?? 0)
        : statusRows.reduce((sum, r) => sum + r.count, 0),
      byStatus: MISSION_HISTORY_STATUSES.map((status) => ({
        status,
        count: countByStatus.get(status) ?? 0,
      })),
      items: rows.map((r) => ({
        id: r.id,
        title: r.title,
        category: r.category,
        status: r.status,
        locationAddress: r.location_address,
        startingPrice: r.starting_price,
        rejectionReason: r.rejection_reason,
        poster: {
          id: r.poster_id,
          fullName: r.poster_name,
          phone: r.poster_phone,
          deleted: r.poster_deleted,
          role: r.poster_role,
        },
        performer: r.performer_id
          ? {
              id: r.performer_id,
              fullName: r.performer_name,
              phone: r.performer_phone,
              deleted: r.performer_deleted ?? false,
            }
          : null,
        applicationsCount: r.applications_count,
        createdAt: r.created_at,
        publishedAt: r.published_at,
        selectedAt: r.selected_at,
        completedAt: r.completed_at,
        archivedAt: r.archived_at,
        endedAt: r.ended_at,
      })),
    };
  }

  // Read-only, per-request detail of the real-time matching engine: which
  // client asked, how it ended, and which craftsman (if any) did the job.
  async getRequestHistory(
    query: RequestHistoryQueryDto,
  ): Promise<HistoryPage<RequestHistoryRow, ServiceRequestStatus>> {
    const conditions = ['1=1'];
    const params: unknown[] = [];
    if (query.date) {
      params.push(query.date);
      conditions.push(
        `(sr.created_at AT TIME ZONE 'UTC')::date = $${params.length}::date`,
      );
    }
    if (query.client?.trim()) {
      params.push(likePattern(query.client));
      const n = params.length;
      conditions.push(`(c.full_name ILIKE $${n} OR c.phone ILIKE $${n})`);
    }
    if (query.artisan?.trim()) {
      params.push(likePattern(query.artisan));
      const n = params.length;
      conditions.push(`(a.full_name ILIKE $${n} OR a.phone ILIKE $${n})`);
    }
    const from = `
      FROM service_requests sr
      JOIN users c ON c.id = sr.client_id
      LEFT JOIN users a ON a.id = sr.craftsman_id`;

    const statusRows: Array<{ status: ServiceRequestStatus; count: number }> =
      await this.dataSource.query(
        `SELECT sr.status::text AS status, COUNT(*)::int AS count ${from}
         WHERE ${conditions.join(' AND ')}
         GROUP BY sr.status`,
        params,
      );

    const listConditions = [...conditions];
    const listParams = [...params];
    if (query.status) {
      listParams.push(query.status);
      listConditions.push(`sr.status::text = $${listParams.length}`);
    }
    listParams.push(query.limit ?? 50, query.offset ?? 0);
    const rows: RequestHistoryDbRow[] = await this.dataSource.query(
      `SELECT
         sr.id, sr.service_category AS category, sr.status::text AS status,
         sr.created_at, sr.assigned_at, sr.started_at, sr.completed_at,
         sr.cancelled_at,
         CASE sr.status::text
           WHEN 'completed' THEN sr.completed_at
           WHEN 'cancelled' THEN sr.cancelled_at
           WHEN 'expired' THEN sr.updated_at
         END AS ended_at,
         c.id AS client_id, c.full_name AS client_name, c.phone AS client_phone,
         c.deleted_at IS NOT NULL AS client_deleted,
         a.id AS craftsman_id, a.full_name AS craftsman_name,
         a.phone AS craftsman_phone,
         a.deleted_at IS NOT NULL AS craftsman_deleted,
         r.stars AS rating_stars
       ${from}
       LEFT JOIN ratings r ON r.service_request_id = sr.id
       WHERE ${listConditions.join(' AND ')}
       ORDER BY sr.created_at DESC, sr.id
       LIMIT $${listParams.length - 1} OFFSET $${listParams.length}`,
      listParams,
    );

    const countByStatus = new Map(statusRows.map((r) => [r.status, r.count]));
    return {
      total: query.status
        ? (countByStatus.get(query.status) ?? 0)
        : statusRows.reduce((sum, r) => sum + r.count, 0),
      byStatus: Object.values(ServiceRequestStatus).map((status) => ({
        status,
        count: countByStatus.get(status) ?? 0,
      })),
      items: rows.map((r) => ({
        id: r.id,
        category: r.category,
        status: r.status,
        client: {
          id: r.client_id,
          fullName: r.client_name,
          phone: r.client_phone,
          deleted: r.client_deleted,
        },
        craftsman: r.craftsman_id
          ? {
              id: r.craftsman_id,
              fullName: r.craftsman_name,
              phone: r.craftsman_phone,
              deleted: r.craftsman_deleted ?? false,
            }
          : null,
        createdAt: r.created_at,
        assignedAt: r.assigned_at,
        startedAt: r.started_at,
        completedAt: r.completed_at,
        cancelledAt: r.cancelled_at,
        endedAt: r.ended_at,
        ratingStars: r.rating_stars,
      })),
    };
  }

  private rangeStart(range: OpsStatsRange): Date | null {
    const now = new Date();
    if (range === 'today') {
      return new Date(
        Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
      );
    }
    if (range === 'week') {
      return new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    }
    return null;
  }
}
