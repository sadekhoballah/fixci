import { Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { INITIAL_RADIUS_METERS } from './matching.constants';

export interface CreatedServiceRequest {
  id: string;
  clientId: string;
  serviceCategory: ServiceCategory;
  latitude: number;
  longitude: number;
}

// All PostGIS-touching queries go through raw SQL rather than the entity API —
// TypeORM round-trips `geography` columns as raw EWKB, so ST_MakePoint/ST_SetSRID
// on write and RETURNING on the atomic UPDATE are far less error-prone written by hand.
@Injectable()
export class MatchingService {
  constructor(private readonly dataSource: DataSource) {}

  // Returns null if this client already has an active request (pending,
  // assigned, in_progress, or awaiting_client_confirmation) — enforced
  // atomically by the service_requests_one_active_per_client partial unique
  // index, not a check-then-insert, so a fast double-tap can't race past it.
  async createServiceRequest(
    clientId: string,
    serviceCategory: ServiceCategory,
    latitude: number,
    longitude: number,
  ): Promise<CreatedServiceRequest | null> {
    try {
      const rows: Array<{ id: string }> = await this.dataSource.query(
        `INSERT INTO "service_requests"
           ("client_id", "service_category", "client_location", "search_radius_meters")
         VALUES ($1, $2, ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography, $5)
         RETURNING "id"`,
        [clientId, serviceCategory, longitude, latitude, INITIAL_RADIUS_METERS],
      );
      return {
        id: rows[0].id,
        clientId,
        serviceCategory,
        latitude,
        longitude,
      };
    } catch (error) {
      if ((error as { code?: string }).code === '23505') {
        return null;
      }
      throw error;
    }
  }

  // Catches the craftsman who logs in / goes available *after* a client's
  // request already exists — runMatchingLoop only samples candidates at the
  // start of each radius round, so a craftsman who comes online between
  // rounds (or after the loop moved to a wider radius) would otherwise wait
  // for the next round's findNearest to happen to pick them up, or miss the
  // request entirely if it's already run out of rounds. Called once, right
  // after presence registration, so this newly-online craftsman gets an
  // immediate request:new for anything still pending within its own
  // (possibly already-expanded) search_radius_meters.
  async findPendingNear(
    category: ServiceCategory,
    longitude: number,
    latitude: number,
  ): Promise<Array<{ id: string; clientId: string; distanceMeters: number }>> {
    const rows: Array<{
      id: string;
      client_id: string;
      distance_meters: string;
    }> = await this.dataSource.query(
      `SELECT "id", "client_id",
              ST_Distance("client_location", ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) AS distance_meters
       FROM "service_requests"
       WHERE "status" = 'pending'
         AND "service_category" = $3
         AND ST_DWithin("client_location", ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, "search_radius_meters")
       ORDER BY distance_meters ASC`,
      [longitude, latitude, category],
    );
    return rows.map((row) => ({
      id: row.id,
      clientId: row.client_id,
      distanceMeters: Number(row.distance_meters),
    }));
  }

  // Fallback candidate source for MatchingGateway's wake-up phase, when
  // Redis presence has nobody live at all: queries craftsman_profiles.location,
  // which PresenceService.setOnline/updateLocation keep as a best-effort
  // "last seen here" marker independent of live Redis membership. Joins
  // districts to mirror the same open-zone gate PresenceService.setOnline
  // enforces on the live path — a wake-up push should never reach a
  // craftsman whose district has since closed. Deliberately ignores
  // is_available: that flag is exactly what drifts stale when a socket
  // drops without a clean disconnect, so it's not trustworthy here.
  // A craftsman who has never once gone online has location IS NULL and is
  // correctly excluded — there is no location to wake them up with.
  async findNearestByLastKnownLocation(
    category: ServiceCategory,
    longitude: number,
    latitude: number,
    excludeCraftsmanIds: string[],
    limit: number,
  ): Promise<Array<{ craftsmanId: string; distanceMeters: number }>> {
    const rows: Array<{ user_id: string; distance_meters: string }> =
      await this.dataSource.query(
        `SELECT cp."user_id",
                ST_Distance(cp."location", ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) AS distance_meters
         FROM "craftsman_profiles" cp
         JOIN "users" u ON u."id" = cp."user_id"
         JOIN "districts" d ON d."id" = u."district_id"
         WHERE cp."service_category" = $3
           AND cp."is_active" = true
           AND cp."location" IS NOT NULL
           AND d."is_artisan_registration_active" = true
           AND NOT (cp."user_id" = ANY($4::uuid[]))
         ORDER BY distance_meters ASC
         LIMIT $5`,
        [longitude, latitude, category, excludeCraftsmanIds, limit],
      );
    return rows.map((row) => ({
      craftsmanId: row.user_id,
      distanceMeters: Number(row.distance_meters),
    }));
  }

  async updateSearchRadius(
    requestId: string,
    radiusMeters: number,
  ): Promise<void> {
    await this.dataSource.query(
      `UPDATE "service_requests" SET "search_radius_meters" = $1, "updated_at" = now()
       WHERE "id" = $2 AND "status" = 'pending'`,
      [radiusMeters, requestId],
    );
  }

  // The WHERE "status" = 'pending' guard is the atomic compare-and-swap: Postgres
  // row-level locking on UPDATE serializes concurrent attempts, so if two craftsmen
  // accept in the same instant, only the first UPDATE actually flips the row and
  // returns a match — the second sees status already changed and affects 0 rows.
  //
  // TypeORM's Postgres driver returns UPDATE/DELETE results as a [rows, affectedCount]
  // tuple (unlike INSERT, which returns the rows array directly) — destructure it,
  // don't treat the tuple itself as the rows array.
  async tryAssign(requestId: string, craftsmanId: string): Promise<boolean> {
    const [rows]: [Array<{ id: string }>, number] = await this.dataSource.query(
      `UPDATE "service_requests"
       SET "status" = 'assigned', "craftsman_id" = $1, "assigned_at" = now(), "updated_at" = now()
       WHERE "id" = $2 AND "status" = 'pending'
       RETURNING "id"`,
      [craftsmanId, requestId],
    );
    return rows.length === 1;
  }

  async expireRequest(requestId: string): Promise<boolean> {
    const [rows]: [Array<{ id: string }>, number] = await this.dataSource.query(
      `UPDATE "service_requests" SET "status" = 'expired', "updated_at" = now()
       WHERE "id" = $1 AND "status" = 'pending'
       RETURNING "id"`,
      [requestId],
    );
    return rows.length === 1;
  }

  // The job lifecycle past assignment: assigned -> in_progress ->
  // awaiting_client_confirmation -> completed, with cancellation possible
  // from either of the first two. Each transition is a single atomic UPDATE
  // scoped to both the expected prior status AND the calling craftsman's own
  // id — same compare-and-swap shape as tryAssign above, and it's what makes
  // "only the assigned craftsman can transition their own job" a property of
  // the query itself rather than a separate ownership check that could race
  // with a concurrent request.
  async startJob(
    requestId: string,
    craftsmanId: string,
  ): Promise<JobTransitionResult | null> {
    return this.transitionJob(
      requestId,
      craftsmanId,
      ['assigned'],
      `"status" = 'in_progress', "started_at" = now()`,
    );
  }

  // The craftsman's side of mutual completion: marks the job as done from
  // their end, but doesn't close it out yet — the client still has to
  // confirm (see confirmCompletion below) before it's truly `completed`.
  async completeJob(
    requestId: string,
    craftsmanId: string,
  ): Promise<JobTransitionResult | null> {
    return this.transitionJob(
      requestId,
      craftsmanId,
      ['in_progress'],
      `"status" = 'awaiting_client_confirmation'`,
    );
  }

  // The client's side of mutual completion — only they can finalize a job
  // the craftsman has marked done, mirroring how only the craftsman can
  // start/complete their own job above. Scoped by client_id instead of
  // craftsman_id for the same compare-and-swap safety.
  async confirmCompletion(
    requestId: string,
    clientId: string,
  ): Promise<ClientConfirmResult | null> {
    const [rows]: [Array<{ id: string; craftsman_id: string }>, number] =
      await this.dataSource.query(
        `UPDATE "service_requests"
         SET "status" = 'completed', "completed_at" = now(), "updated_at" = now()
         WHERE "id" = $1 AND "client_id" = $2 AND "status" = 'awaiting_client_confirmation'
         RETURNING "id", "craftsman_id"`,
        [requestId, clientId],
      );
    if (rows.length === 0) return null;
    return { requestId: rows[0].id, craftsmanId: rows[0].craftsman_id };
  }

  async cancelJob(
    requestId: string,
    craftsmanId: string,
  ): Promise<JobTransitionResult | null> {
    return this.transitionJob(
      requestId,
      craftsmanId,
      ['assigned', 'in_progress'],
      `"status" = 'cancelled', "cancelled_at" = now()`,
    );
  }

  // A client can back out any time before the job is actually underway —
  // still searching (pending, nobody assigned yet) or waiting on the
  // craftsman they matched with (assigned). Once work has started
  // (in_progress) it's the craftsman's transitions that own the job, not
  // the client's. If the request is still 'pending', this alone doesn't stop
  // the in-memory runMatchingLoop for it — every write it makes is itself
  // guarded by a status check, so it'd find 0 rows and no-op — but the
  // caller (MatchingController) also calls MatchingGateway.abortMatchingLoop
  // right after this succeeds, which does actively stop it rather than
  // letting it run out its ~4 minute worst case.
  async cancelByClient(
    requestId: string,
    clientId: string,
  ): Promise<ClientCancelResult | null> {
    const [rows]: [Array<{ id: string; craftsman_id: string | null }>, number] =
      await this.dataSource.query(
        `UPDATE "service_requests"
       SET "status" = 'cancelled', "cancelled_at" = now(), "updated_at" = now()
       WHERE "id" = $1 AND "client_id" = $2 AND "status" = ANY($3)
       RETURNING "id", "craftsman_id"`,
        [requestId, clientId, ['pending', 'assigned']],
      );
    if (rows.length === 0) return null;
    return { requestId: rows[0].id, craftsmanId: rows[0].craftsman_id };
  }

  // Only the request's own client, only once the craftsman's work is fully
  // wrapped up (completed — i.e. both sides already confirmed), and only
  // once (the unique index on ratings.service_request_id is the hard
  // backstop against a duplicate submission racing this check). Recomputes
  // the craftsman's aggregate rating from the ratings table itself rather
  // than incremental math — negligible cost at this volume, no drift risk.
  async submitRating(
    requestId: string,
    clientId: string,
    stars: number,
    comment: string | null,
  ): Promise<RatingResult | null> {
    return this.dataSource.transaction(async (manager) => {
      const requests: Array<{ craftsman_id: string | null }> =
        await manager.query(
          `SELECT "craftsman_id" FROM "service_requests"
           WHERE "id" = $1 AND "client_id" = $2 AND "status" = 'completed'
           FOR UPDATE`,
          [requestId, clientId],
        );
      if (requests.length === 0 || !requests[0].craftsman_id) {
        return null;
      }
      const craftsmanId = requests[0].craftsman_id;

      const existing: unknown[] = await manager.query(
        `SELECT 1 FROM "ratings" WHERE "service_request_id" = $1`,
        [requestId],
      );
      if (existing.length > 0) return null;

      await manager.query(
        `INSERT INTO "ratings"
           ("service_request_id", "client_id", "craftsman_id", "stars", "comment")
         VALUES ($1, $2, $3, $4, $5)`,
        [requestId, clientId, craftsmanId, stars, comment],
      );

      await manager.query(
        `UPDATE "craftsman_profiles"
         SET "average_rating" = (
               SELECT avg("stars") FROM "ratings" WHERE "craftsman_id" = $1
             ),
             "ratings_count" = (
               SELECT count(*) FROM "ratings" WHERE "craftsman_id" = $1
             )
         WHERE "user_id" = $1`,
        [craftsmanId],
      );

      return { requestId, stars, comment };
    });
  }

  private async transitionJob(
    requestId: string,
    craftsmanId: string,
    fromStatuses: string[],
    setClause: string,
  ): Promise<JobTransitionResult | null> {
    const [rows]: [Array<{ id: string; client_id: string }>, number] =
      await this.dataSource.query(
        `UPDATE "service_requests"
         SET ${setClause}, "updated_at" = now()
         WHERE "id" = $1 AND "craftsman_id" = $2 AND "status" = ANY($3)
         RETURNING "id", "client_id"`,
        [requestId, craftsmanId, fromStatuses],
      );
    if (rows.length === 0) return null;
    return { requestId: rows[0].id, clientId: rows[0].client_id };
  }
}

export interface JobTransitionResult {
  requestId: string;
  clientId: string;
}

export interface ClientCancelResult {
  requestId: string;
  craftsmanId: string | null;
}

export interface ClientConfirmResult {
  requestId: string;
  craftsmanId: string;
}

export interface RatingResult {
  requestId: string;
  stars: number;
  comment: string | null;
}
