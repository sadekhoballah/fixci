import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { User } from '../database/entities/user.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { UserRole } from '../database/enums/user-role.enum';

export interface ClientMe {
  fullName: string | null;
  phone: string;
  idVerified: boolean;
  // False only ever means an admin rejected this account (see
  // AdminService.deactivateClient) — every account starts true.
  isActive: boolean;
  completedMissionsCount: number;
  // The client's district's country — mirrors CraftsmanMe.countryCode
  // (see CraftsmenService.getMe). Lets the mobile Missions board filter the
  // district picker down to the caller's own country instead of listing
  // every country's districts in one list (see MissionsBoardScreen).
  countryCode: string;
}

export interface ActiveRequest {
  requestId: string;
  serviceCategory: string;
  status:
    'pending' | 'assigned' | 'in_progress' | 'awaiting_client_confirmation';
  craftsmanFullName: string | null;
  craftsmanPhone: string | null;
}

interface ActiveRequestRow {
  id: string;
  service_category: string;
  status:
    'pending' | 'assigned' | 'in_progress' | 'awaiting_client_confirmation';
  craftsman_full_name: string | null;
  craftsman_phone: string | null;
}

export interface RequestHistoryItem {
  requestId: string;
  serviceCategory: string;
  status: string;
  craftsmanFullName: string | null;
  createdAt: Date;
  assignedAt: Date | null;
  startedAt: Date | null;
  completedAt: Date | null;
  cancelledAt: Date | null;
  ratingStars: number | null;
  ratingComment: string | null;
}

interface RequestHistoryRow {
  id: string;
  service_category: string;
  status: string;
  craftsman_full_name: string | null;
  created_at: Date;
  assigned_at: Date | null;
  started_at: Date | null;
  completed_at: Date | null;
  cancelled_at: Date | null;
  rating_stars: number | null;
  rating_comment: string | null;
}

@Injectable()
export class ClientsService {
  constructor(
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    @InjectRepository(ClientProfile)
    private readonly clientProfileRepository: Repository<ClientProfile>,
    private readonly dataSource: DataSource,
  ) {}

  async getMe(userId: string): Promise<ClientMe> {
    const { user, profile } = await this.findClientByUserId(userId);

    const [{ count }]: [{ count: string }] = await this.dataSource.query(
      `SELECT count(*) FROM "service_requests"
       WHERE "client_id" = $1 AND "status" = 'completed'`,
      [userId],
    );

    return {
      fullName: user.fullName,
      // Non-null assertion safe here: userId always comes from AuthGuard,
      // which never resolves to a deleted (phone: null) account.
      phone: user.phone!,
      idVerified: profile.idVerified,
      isActive: profile.isActive,
      completedMissionsCount: Number(count),
      countryCode: user.district.countryCode,
    };
  }

  // Lets a rejected (isActive: false) client attach a fresh ID photo without
  // going through a whole new registration — mirrors
  // CraftsmenService.resubmitIdCard. Un-deactivates them (isActive: true) so
  // they drop back into AdminService.getPendingVerifications' queue for
  // another look; idVerified stays false either way, for the admin to decide
  // again.
  async resubmitIdCard(
    userId: string,
    idCardStorageKey: string,
  ): Promise<void> {
    await this.findClientByUserId(userId);
    await this.clientProfileRepository.update(
      { userId },
      { idCardStorageKey, isActive: true },
    );
  }

  // Ground truth for "what's my request actually doing right now" — unlike
  // the craftsman side (getActiveJob), the client app has no other way to
  // recover this: it otherwise relies entirely on live socket pushes, which
  // a backgrounded app / dropped connection can silently miss. Called on
  // app-resume (see ServiceRequestController.handleAppResumed) alongside the
  // socket rejoin, so a client who missed a push still sees the true status
  // once they're back. Same active-status set as the one-request-per-client
  // unique index.
  async getActiveRequest(userId: string): Promise<ActiveRequest | null> {
    await this.findClientByUserId(userId);

    const rows: ActiveRequestRow[] = await this.dataSource.query(
      `SELECT sr."id", sr."service_category", sr."status",
              u."full_name" AS craftsman_full_name, u."phone" AS craftsman_phone
       FROM "service_requests" sr
       LEFT JOIN "users" u ON u."id" = sr."craftsman_id"
       WHERE sr."client_id" = $1
         AND sr."status" IN ('pending', 'assigned', 'in_progress', 'awaiting_client_confirmation')
       ORDER BY sr."created_at" DESC
       LIMIT 1`,
      [userId],
    );
    if (rows.length === 0) return null;

    const row = rows[0];
    return {
      requestId: row.id,
      serviceCategory: row.service_category,
      status: row.status,
      craftsmanFullName: row.craftsman_full_name,
      craftsmanPhone: row.craftsman_phone,
    };
  }

  // Every request this client ever made, past or present — backs the
  // Historique tab, mirroring CraftsmenService.getJobHistory's shape.
  async getRequestHistory(
    userId: string,
    limit: number,
    offset: number,
  ): Promise<RequestHistoryItem[]> {
    await this.findClientByUserId(userId);

    const rows: RequestHistoryRow[] = await this.dataSource.query(
      `SELECT sr."id", sr."service_category", sr."status", sr."created_at",
              sr."assigned_at", sr."started_at", sr."completed_at", sr."cancelled_at",
              u."full_name" AS craftsman_full_name,
              r."stars" AS rating_stars, r."comment" AS rating_comment
       FROM "service_requests" sr
       LEFT JOIN "users" u ON u."id" = sr."craftsman_id"
       LEFT JOIN "ratings" r ON r."service_request_id" = sr."id"
       WHERE sr."client_id" = $1
       ORDER BY sr."created_at" DESC
       LIMIT $2 OFFSET $3`,
      [userId, limit, offset],
    );

    return rows.map((row) => ({
      requestId: row.id,
      serviceCategory: row.service_category,
      status: row.status,
      craftsmanFullName: row.craftsman_full_name,
      createdAt: row.created_at,
      assignedAt: row.assigned_at,
      startedAt: row.started_at,
      completedAt: row.completed_at,
      cancelledAt: row.cancelled_at,
      ratingStars: row.rating_stars === null ? null : Number(row.rating_stars),
      ratingComment: row.rating_comment,
    }));
  }

  private async findClientByUserId(
    userId: string,
  ): Promise<{ user: User; profile: ClientProfile }> {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: { district: true },
    });
    if (!user || user.role !== UserRole.CLIENT) {
      throw new NotFoundException('No client account for this user');
    }
    const profile = await this.clientProfileRepository.findOne({
      where: { userId: user.id },
    });
    if (!profile) {
      throw new NotFoundException('No client profile for this account');
    }
    return { user, profile };
  }
}
