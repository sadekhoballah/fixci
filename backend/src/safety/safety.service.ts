import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { ReportReason } from '../database/enums/report-reason.enum';
import { ReportStatus } from '../database/enums/report-status.enum';
import { ReportUserDto } from './dto/report-user.dto';

export interface BlockedUserItem {
  userId: string;
  fullName: string | null;
  phone: string | null;
  blockedAt: Date;
}

export interface PendingReport {
  id: string;
  reporterId: string;
  reporterFullName: string | null;
  reporterPhone: string | null;
  reportedUserId: string;
  reportedUserFullName: string | null;
  reportedUserPhone: string | null;
  reason: ReportReason;
  message: string | null;
  contextType: 'mission' | 'service_request' | null;
  contextId: string | null;
  createdAt: Date;
}

// Backs both the user-facing report/block endpoints (SafetyController,
// mounted at /users alongside UsersController) and the enforcement checks
// every other module needs (MissionsService, MatchingGateway) — kept as raw
// SQL throughout rather than the Repository API, same rationale as
// MissionsService: no geography columns here, but it keeps this service's
// style consistent with the one other module (Missions) it's most tightly
// coupled to, and the admin queue's query is a join raw SQL handles more
// plainly than the Repository API would.
@Injectable()
export class SafetyService {
  constructor(private readonly dataSource: DataSource) {}

  // Idempotent — ON CONFLICT DO NOTHING, so tapping "Bloquer" twice (e.g. a
  // retried request) is a harmless no-op rather than a duplicate-key 500.
  async blockUser(blockerId: string, blockedUserId: string): Promise<void> {
    if (blockerId === blockedUserId) {
      throw new BadRequestException('You cannot block yourself');
    }
    await this.dataSource.query(
      `INSERT INTO "user_blocks" ("blocker_id", "blocked_user_id")
       VALUES ($1, $2)
       ON CONFLICT ("blocker_id", "blocked_user_id") DO NOTHING`,
      [blockerId, blockedUserId],
    );
  }

  async unblockUser(blockerId: string, blockedUserId: string): Promise<void> {
    await this.dataSource.query(
      `DELETE FROM "user_blocks" WHERE "blocker_id" = $1 AND "blocked_user_id" = $2`,
      [blockerId, blockedUserId],
    );
  }

  // Only the blocks *this user initiated* — the "Utilisateurs bloqués"
  // management list is about what they can undo, not who blocked them (that
  // stays invisible to them, same as everywhere else this is enforced).
  async getBlockedUsers(userId: string): Promise<BlockedUserItem[]> {
    const rows: Array<{
      user_id: string;
      full_name: string | null;
      phone: string | null;
      blocked_at: Date;
    }> = await this.dataSource.query(
      `SELECT u."id" AS user_id, u."full_name", u."phone", ub."created_at" AS blocked_at
       FROM "user_blocks" ub
       JOIN "users" u ON u."id" = ub."blocked_user_id"
       WHERE ub."blocker_id" = $1
       ORDER BY ub."created_at" DESC`,
      [userId],
    );
    return rows.map((row) => ({
      userId: row.user_id,
      fullName: row.full_name,
      phone: row.phone,
      blockedAt: row.blocked_at,
    }));
  }

  // Every id blocked in EITHER direction relative to userId — the shape
  // every enforcement call site needs (missions board/apply/select,
  // real-time matching candidate filtering), since a block is always
  // enforced bidirectionally regardless of who initiated it. A plain Set,
  // not a query per pair, so a caller filtering a whole candidate list only
  // pays for one round trip.
  async getBlockedCounterpartIds(userId: string): Promise<Set<string>> {
    const rows: Array<{ counterpart_id: string }> = await this.dataSource.query(
      `SELECT "blocked_user_id" AS counterpart_id FROM "user_blocks" WHERE "blocker_id" = $1
       UNION
       SELECT "blocker_id" AS counterpart_id FROM "user_blocks" WHERE "blocked_user_id" = $1`,
      [userId],
    );
    return new Set(rows.map((row) => row.counterpart_id));
  }

  // Single-pair check for MissionsService's apply/select — cheaper than
  // pulling the full counterpart set when only one relationship matters.
  async isBlockedEitherWay(userIdA: string, userIdB: string): Promise<boolean> {
    const rows: unknown[] = await this.dataSource.query(
      `SELECT 1 FROM "user_blocks"
       WHERE ("blocker_id" = $1 AND "blocked_user_id" = $2)
          OR ("blocker_id" = $2 AND "blocked_user_id" = $1)
       LIMIT 1`,
      [userIdA, userIdB],
    );
    return rows.length > 0;
  }

  async reportUser(
    reporterId: string,
    reportedUserId: string,
    dto: ReportUserDto,
  ): Promise<{ id: string }> {
    if (reporterId === reportedUserId) {
      throw new BadRequestException('You cannot report yourself');
    }
    const rows: Array<{ id: string }> = await this.dataSource.query(
      `INSERT INTO "user_reports"
         ("reporter_id", "reported_user_id", "reason", "message", "context_type", "context_id")
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING "id"`,
      [
        reporterId,
        reportedUserId,
        dto.reason,
        dto.message ?? null,
        dto.contextType ?? null,
        dto.contextId ?? null,
      ],
    );
    return { id: rows[0].id };
  }

  // Admin queue — pending only, oldest first, mirrors
  // AdminService.getPendingVerifications' "act is how it leaves the queue"
  // shape.
  async getPendingReports(): Promise<PendingReport[]> {
    const rows: Array<Record<string, unknown>> = await this.dataSource.query(
      `SELECT ur."id", ur."reporter_id", reporter."full_name" AS reporter_full_name,
              reporter."phone" AS reporter_phone,
              ur."reported_user_id", reported."full_name" AS reported_user_full_name,
              reported."phone" AS reported_user_phone,
              ur."reason", ur."message", ur."context_type", ur."context_id", ur."created_at"
       FROM "user_reports" ur
       JOIN "users" reporter ON reporter."id" = ur."reporter_id"
       JOIN "users" reported ON reported."id" = ur."reported_user_id"
       WHERE ur."status" = 'pending'
       ORDER BY ur."created_at" ASC`,
    );
    return rows.map((row) => ({
      id: row.id as string,
      reporterId: row.reporter_id as string,
      reporterFullName: row.reporter_full_name as string | null,
      reporterPhone: row.reporter_phone as string | null,
      reportedUserId: row.reported_user_id as string,
      reportedUserFullName: row.reported_user_full_name as string | null,
      reportedUserPhone: row.reported_user_phone as string | null,
      reason: row.reason as ReportReason,
      message: row.message as string | null,
      contextType: row.context_type as 'mission' | 'service_request' | null,
      contextId: row.context_id as string | null,
      createdAt: row.created_at as Date,
    }));
  }

  // Looked up first by AdminService.resolveReport so it knows which user id
  // to act on before deciding whether to also deactivate them.
  async getReportedUserId(reportId: string): Promise<string> {
    const rows: Array<{ reported_user_id: string }> = await this.dataSource.query(
      `SELECT "reported_user_id" FROM "user_reports" WHERE "id" = $1`,
      [reportId],
    );
    if (rows.length === 0) {
      throw new NotFoundException('Report not found');
    }
    return rows[0].reported_user_id;
  }

  async markReportResolved(
    reportId: string,
    status: ReportStatus.RESOLVED | ReportStatus.DISMISSED,
    note?: string,
  ): Promise<void> {
    const [, affected]: [unknown[], number] = await this.dataSource.query(
      `UPDATE "user_reports"
       SET "status" = $1, "admin_note" = $2, "resolved_at" = now()
       WHERE "id" = $3 AND "status" = 'pending'
       RETURNING "id"`,
      [status, note ?? null, reportId],
    );
    if (!affected) {
      throw new NotFoundException(
        'Report not found (or already resolved)',
      );
    }
  }
}
