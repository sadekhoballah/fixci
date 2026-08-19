import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DataSource } from 'typeorm';
import { MissionStatus } from '../database/enums/mission-status.enum';
import { MissionApplicationStatus } from '../database/enums/mission-application-status.enum';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { MissionTimingPreference } from '../database/enums/mission-timing-preference.enum';
import { CreateMissionDto } from './dto/create-mission.dto';
import { UpdateMissionDto } from './dto/update-mission.dto';
import { BrowseMissionsQueryDto } from './dto/browse-missions-query.dto';
import { ApplyToMissionDto } from './dto/apply-to-mission.dto';

// Row shape shared by browse/detail/mine — never includes the raw geography
// column itself (see Mission.location's EWKB round-trip caveat), only its
// ST_X/ST_Y-extracted latitude/longitude; locationAddress remains the
// human-facing location field, alongside a computed distanceMeters when the
// caller supplied a position.
export interface MissionListItem {
  id: string;
  posterId: string;
  title: string;
  description: string;
  category: ServiceCategory | null;
  locationAddress: string;
  // Raw point, extracted from the geography column — see the ST_X/ST_Y note
  // on SELECT_COLUMNS below. Exists purely so the mobile client can reverse-
  // geocode a human-readable address client-side (no Maps API key
  // configured — see the CreateMissionDto note); never fed back into a
  // write, unlike locationAddress.
  latitude: number;
  longitude: number;
  photoStorageKeys: string[] | null;
  status: MissionStatus;
  rejectionReason: string | null;
  timingPreference: MissionTimingPreference;
  scheduledDayOfWeek: number | null;
  scheduledHour: number | null;
  // Numeric — kept as a string (never Number()'d) so the amount round-trips
  // exactly, same convention as MissionApplicant.averageRating.
  startingPrice: string | null;
  distanceMeters: number | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface MissionDetail extends MissionListItem {
  isOwnMission: boolean;
  myApplicationStatus: MissionApplicationStatus | null;
  // Only populated when isOwnMission or myApplicationStatus === 'selected' —
  // see the class-level note on getMissionDetail below.
  posterFullName: string | null;
  posterPhone: string | null;
  // Owner-only (null for everyone else) — lets the "Voir les candidatures"
  // button on the mobile detail screen show a count without a second round
  // trip to GET /missions/:id/applications.
  applicantsCount: number | null;
}

export interface MineMissionItem extends MissionListItem {
  roleInMission: 'poster' | 'applicant';
  myApplicationStatus: MissionApplicationStatus | null;
}

export interface MissionApplicant {
  applicationId: string;
  applicantId: string;
  applicantFullName: string | null;
  applicantPhone: string | null;
  applicantRole: string;
  status: MissionApplicationStatus;
  message: string | null;
  distanceMeters: number;
  // Craftsman-only — see AdminService's own averageRating shape. Clients
  // aren't rated in this product, so these come back null for a client
  // applicant rather than a fabricated value.
  averageRating: string | null;
  ratingsCount: number | null;
  appliedAt: Date;
}

const SELECT_COLUMNS = `
  "id", "poster_id", "title", "description", "category", "location_address",
  ST_Y("location"::geometry) AS latitude, ST_X("location"::geometry) AS longitude,
  "photo_storage_keys", "status", "rejection_reason", "timing_preference",
  "scheduled_day_of_week", "scheduled_hour", "starting_price",
  "created_at", "updated_at"
`;

function mapRow(row: Record<string, unknown>): MissionListItem {
  return {
    id: row.id as string,
    posterId: row.poster_id as string,
    title: row.title as string,
    description: row.description as string,
    category: row.category as ServiceCategory | null,
    locationAddress: row.location_address as string,
    latitude: Number(row.latitude),
    longitude: Number(row.longitude),
    photoStorageKeys: row.photo_storage_keys as string[] | null,
    status: row.status as MissionStatus,
    rejectionReason: row.rejection_reason as string | null,
    timingPreference: row.timing_preference as MissionTimingPreference,
    scheduledDayOfWeek: row.scheduled_day_of_week as number | null,
    scheduledHour: row.scheduled_hour as number | null,
    startingPrice: row.starting_price as string | null,
    distanceMeters:
      row.distance_meters == null ? null : Number(row.distance_meters),
    createdAt: row.created_at as Date,
    updatedAt: row.updated_at as Date,
  };
}

// All PostGIS-touching queries go through raw SQL rather than the entity
// API, same rationale as MatchingService: `geography` columns round-trip as
// raw EWKB on plain find/save, so coordinate reads/writes go through
// ST_MakePoint/ST_Distance by hand. Status-only transitions that never touch
// `location`/`applicant_location` use dataSource.query too, for consistency
// with the rest of this service and because every one of them needs a
// compare-and-swap WHERE clause anyway (mirrors MatchingService.tryAssign).
@Injectable()
export class MissionsService {
  constructor(private readonly dataSource: DataSource) {}

  async createMission(
    posterId: string,
    dto: CreateMissionDto,
  ): Promise<{ id: string; status: MissionStatus }> {
    const rows: Array<{ id: string; status: MissionStatus }> =
      await this.dataSource.query(
        `INSERT INTO "missions"
           ("poster_id", "title", "description", "category", "location_address",
            "location", "photo_storage_keys", "timing_preference",
            "scheduled_day_of_week", "scheduled_hour", "starting_price")
         VALUES ($1, $2, $3, $4, $5, ST_SetSRID(ST_MakePoint($6, $7), 4326)::geography, $8, $9, $10, $11, $12)
         RETURNING "id", "status"`,
        [
          posterId,
          dto.title,
          dto.description,
          dto.category ?? null,
          dto.locationAddress,
          dto.longitude,
          dto.latitude,
          dto.photoStorageKeys ?? null,
          dto.timingPreference ?? MissionTimingPreference.UNSPECIFIED,
          dto.scheduledDayOfWeek ?? null,
          dto.scheduledHour ?? null,
          dto.startingPrice ?? null,
        ],
      );
    return { id: rows[0].id, status: rows[0].status };
  }

  // Public board — approved_published only. Sorted by distance when the
  // caller supplied a position, otherwise most-recent-first.
  async browseMissions(
    query: BrowseMissionsQueryDto,
    limit: number,
    offset: number,
  ): Promise<MissionListItem[]> {
    const hasPosition = query.latitude != null && query.longitude != null;
    const conditions: string[] = [`"status" = 'approved_published'`];
    const params: unknown[] = [];

    if (hasPosition) {
      params.push(query.longitude, query.latitude);
    }
    if (query.category) {
      params.push(query.category);
      conditions.push(`"category" = $${params.length}`);
    }
    params.push(limit, offset);

    const distanceExpr = hasPosition
      ? `ST_Distance("location", ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography)`
      : `NULL`;
    const orderBy = hasPosition ? `distance_meters ASC` : `"created_at" DESC`;

    const rows: Array<Record<string, unknown>> = await this.dataSource.query(
      `SELECT ${SELECT_COLUMNS}, ${distanceExpr} AS distance_meters
       FROM "missions"
       WHERE ${conditions.join(' AND ')}
       ORDER BY ${orderBy}
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params,
    );
    return rows.map(mapRow);
  }

  // Privacy rule: the poster's name/phone are only ever included when the
  // caller IS the poster, or is the applicant this mission has SELECTED —
  // never to a plain browser, mirroring "the owner reaches out to the
  // candidate", not the other way around.
  async getMissionDetail(
    missionId: string,
    callerId: string,
    latitude?: number,
    longitude?: number,
  ): Promise<MissionDetail> {
    const hasPosition = latitude != null && longitude != null;
    const params: unknown[] = hasPosition
      ? [longitude, latitude, missionId]
      : [missionId];
    const distanceExpr = hasPosition
      ? `ST_Distance("location", ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography)`
      : `NULL`;

    const rows: Array<Record<string, unknown>> = await this.dataSource.query(
      `SELECT ${SELECT_COLUMNS}, ${distanceExpr} AS distance_meters
       FROM "missions"
       WHERE "id" = $${params.length}`,
      params,
    );
    if (rows.length === 0) {
      throw new NotFoundException('Mission not found');
    }
    const mission = mapRow(rows[0]);
    const isOwnMission = mission.posterId === callerId;

    const applicationRows: Array<{
      status: MissionApplicationStatus;
    }> = await this.dataSource.query(
      `SELECT "status" FROM "mission_applications"
       WHERE "mission_id" = $1 AND "applicant_id" = $2 AND "status" != 'withdrawn'`,
      [missionId, callerId],
    );
    const myApplicationStatus = applicationRows[0]?.status ?? null;

    let posterFullName: string | null = null;
    let posterPhone: string | null = null;
    if (
      isOwnMission ||
      myApplicationStatus === MissionApplicationStatus.SELECTED
    ) {
      const posterRows: Array<{
        full_name: string | null;
        phone: string | null;
      }> = await this.dataSource.query(
        `SELECT "full_name", "phone" FROM "users" WHERE "id" = $1`,
        [mission.posterId],
      );
      posterFullName = posterRows[0]?.full_name ?? null;
      posterPhone = posterRows[0]?.phone ?? null;
    }

    let applicantsCount: number | null = null;
    if (isOwnMission) {
      const countRows: Array<{ count: string }> = await this.dataSource.query(
        `SELECT count(*) FROM "mission_applications"
         WHERE "mission_id" = $1 AND "status" != 'withdrawn'`,
        [missionId],
      );
      applicantsCount = Number(countRows[0]?.count ?? 0);
    }

    return {
      ...mission,
      isOwnMission,
      myApplicationStatus,
      posterFullName,
      posterPhone,
      applicantsCount,
    };
  }

  // Feeds the "Mes missions" tab: everything the caller posted, union
  // everything they applied to (excluding withdrawn applications), deduped,
  // most-recently-updated first. This is also where completed/archived
  // missions live for both parties — there is no separate archive endpoint.
  async getMyMissions(
    callerId: string,
    limit: number,
    offset: number,
  ): Promise<MineMissionItem[]> {
    const rows: Array<Record<string, unknown>> = await this.dataSource.query(
      `WITH combined AS (
         SELECT m."id" AS mission_id,
                'poster'::text AS role_in_mission,
                NULL::mission_application_status_enum AS my_application_status
         FROM "missions" m
         WHERE m."poster_id" = $1
         UNION
         SELECT m."id" AS mission_id,
                'applicant'::text AS role_in_mission,
                ma."status" AS my_application_status
         FROM "missions" m
         JOIN "mission_applications" ma ON ma."mission_id" = m."id"
         WHERE ma."applicant_id" = $1 AND ma."status" != 'withdrawn'
       )
       SELECT ${SELECT_COLUMNS}, NULL::numeric AS distance_meters,
              c."role_in_mission", c."my_application_status"
       FROM combined c
       JOIN "missions" m ON m."id" = c."mission_id"
       ORDER BY m."updated_at" DESC
       LIMIT $2 OFFSET $3`,
      [callerId, limit, offset],
    );
    return rows.map((row) => ({
      ...mapRow(row),
      roleInMission: row.role_in_mission as 'poster' | 'applicant',
      myApplicationStatus:
        (row.my_application_status as MissionApplicationStatus | null) ?? null,
    }));
  }

  // Edit-and-resubmit after a rejection only — every other status is a 409.
  async updateMission(
    missionId: string,
    posterId: string,
    dto: UpdateMissionDto,
  ): Promise<void> {
    const setClauses = [
      `"status" = 'pending_moderation'`,
      `"rejection_reason" = NULL`,
      `"updated_at" = now()`,
    ];
    const params: unknown[] = [];

    if (dto.title !== undefined) {
      params.push(dto.title);
      setClauses.push(`"title" = $${params.length}`);
    }
    if (dto.description !== undefined) {
      params.push(dto.description);
      setClauses.push(`"description" = $${params.length}`);
    }
    if (dto.category !== undefined) {
      params.push(dto.category);
      setClauses.push(`"category" = $${params.length}`);
    }
    if (dto.locationAddress !== undefined) {
      params.push(dto.locationAddress);
      setClauses.push(`"location_address" = $${params.length}`);
    }
    if (dto.latitude != null && dto.longitude != null) {
      params.push(dto.longitude, dto.latitude);
      setClauses.push(
        `"location" = ST_SetSRID(ST_MakePoint($${params.length - 1}, $${params.length}), 4326)::geography`,
      );
    }
    if (dto.photoStorageKeys !== undefined) {
      params.push(dto.photoStorageKeys);
      setClauses.push(`"photo_storage_keys" = $${params.length}`);
    }
    // Set as a trio whenever timingPreference is touched at all — an edit
    // that moves away from SCHEDULED must also null out the now-stale
    // day/hour, not just leave them behind (the DTO only requires
    // scheduledDayOfWeek/scheduledHour when timingPreference IS SCHEDULED).
    if (dto.timingPreference !== undefined) {
      params.push(dto.timingPreference);
      setClauses.push(`"timing_preference" = $${params.length}`);
      params.push(dto.scheduledDayOfWeek ?? null);
      setClauses.push(`"scheduled_day_of_week" = $${params.length}`);
      params.push(dto.scheduledHour ?? null);
      setClauses.push(`"scheduled_hour" = $${params.length}`);
    }
    if (dto.startingPrice !== undefined) {
      params.push(dto.startingPrice);
      setClauses.push(`"starting_price" = $${params.length}`);
    }

    params.push(missionId, posterId);
    const [rows]: [Array<{ id: string }>, number] = await this.dataSource.query(
      `UPDATE "missions" SET ${setClauses.join(', ')}
       WHERE "id" = $${params.length - 1} AND "poster_id" = $${params.length} AND "status" = 'rejected'
       RETURNING "id"`,
      params,
    );
    if (rows.length === 0) {
      throw new ConflictException(
        'This mission cannot be edited (not yours, or not currently rejected)',
      );
    }
  }

  async withdrawMission(missionId: string, posterId: string): Promise<void> {
    const [rows]: [Array<{ id: string }>, number] = await this.dataSource.query(
      `UPDATE "missions"
       SET "status" = 'archived', "archived_at" = now(), "updated_at" = now()
       WHERE "id" = $1 AND "poster_id" = $2
         AND "status" = ANY($3)
       RETURNING "id"`,
      [
        missionId,
        posterId,
        [
          MissionStatus.PENDING_MODERATION,
          MissionStatus.APPROVED_PUBLISHED,
          MissionStatus.REJECTED,
        ],
      ],
    );
    if (rows.length === 0) {
      throw new ConflictException(
        'This mission cannot be withdrawn (not yours, or already in progress/completed/archived)',
      );
    }
  }

  // Returns the poster's id so the controller can notify them — 403 if the
  // caller owns the mission (posting to your own board entry makes no
  // sense), 409 if it isn't currently published or they already applied.
  async applyToMission(
    missionId: string,
    applicantId: string,
    dto: ApplyToMissionDto,
  ): Promise<{ applicationId: string; posterId: string }> {
    const missions: Array<{
      id: string;
      poster_id: string;
      status: MissionStatus;
    }> = await this.dataSource.query(
      `SELECT "id", "poster_id", "status" FROM "missions" WHERE "id" = $1`,
      [missionId],
    );
    if (missions.length === 0) {
      throw new NotFoundException('Mission not found');
    }
    const mission = missions[0];
    if (mission.poster_id === applicantId) {
      throw new ForbiddenException('You cannot apply to your own mission');
    }
    if (mission.status !== MissionStatus.APPROVED_PUBLISHED) {
      throw new ConflictException('This mission is not open for applications');
    }

    try {
      const rows: Array<{ id: string }> = await this.dataSource.query(
        `INSERT INTO "mission_applications"
           ("mission_id", "applicant_id", "applicant_location", "message")
         VALUES ($1, $2, ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography, $5)
         RETURNING "id"`,
        [
          missionId,
          applicantId,
          dto.longitude,
          dto.latitude,
          dto.message ?? null,
        ],
      );
      return { applicationId: rows[0].id, posterId: mission.poster_id };
    } catch (error) {
      if ((error as { code?: string }).code === '23505') {
        throw new ConflictException('You already applied to this mission');
      }
      throw error;
    }
  }

  async getApplicants(
    missionId: string,
    ownerId: string,
  ): Promise<MissionApplicant[]> {
    const missions: Array<{ poster_id: string }> = await this.dataSource.query(
      `SELECT "poster_id" FROM "missions" WHERE "id" = $1`,
      [missionId],
    );
    if (missions.length === 0) {
      throw new NotFoundException('Mission not found');
    }
    if (missions[0].poster_id !== ownerId) {
      throw new ForbiddenException(
        'Only the mission owner can view applicants',
      );
    }

    const rows: Array<Record<string, unknown>> = await this.dataSource.query(
      `SELECT ma."id" AS application_id, ma."applicant_id", u."full_name", u."phone",
              u."role", ma."status", ma."message", ma."created_at",
              ST_Distance(m."location", ma."applicant_location") AS distance_meters,
              cp."average_rating", cp."ratings_count"
       FROM "mission_applications" ma
       JOIN "missions" m ON m."id" = ma."mission_id"
       JOIN "users" u ON u."id" = ma."applicant_id"
       LEFT JOIN "craftsman_profiles" cp ON cp."user_id" = ma."applicant_id"
       WHERE ma."mission_id" = $1 AND ma."status" != 'withdrawn'
       ORDER BY ma."created_at" ASC`,
      [missionId],
    );
    return rows.map((row) => ({
      applicationId: row.application_id as string,
      applicantId: row.applicant_id as string,
      applicantFullName: row.full_name as string | null,
      applicantPhone: row.phone as string | null,
      applicantRole: row.role as string,
      status: row.status as MissionApplicationStatus,
      message: row.message as string | null,
      distanceMeters: Number(row.distance_meters),
      averageRating: row.average_rating as string | null,
      ratingsCount: row.ratings_count as number | null,
      appliedAt: row.created_at as Date,
    }));
  }

  // Transaction: the picked applicant -> selected, every other still-pending
  // applicant on this mission -> not_selected (SILENTLY — no notification to
  // the non-retained pool, see the push-flood lesson in commit 129fc36),
  // mission -> in_progress. Returns the selected applicant's id so the
  // controller can notify them (them alone).
  async selectApplicant(
    missionId: string,
    ownerId: string,
    applicationId: string,
  ): Promise<{ applicantId: string }> {
    return this.dataSource.transaction(async (manager) => {
      const missions: Array<{
        id: string;
        poster_id: string;
        status: MissionStatus;
      }> = await manager.query(
        `SELECT "id", "poster_id", "status" FROM "missions" WHERE "id" = $1 FOR UPDATE`,
        [missionId],
      );
      if (missions.length === 0) {
        throw new NotFoundException('Mission not found');
      }
      if (missions[0].poster_id !== ownerId) {
        throw new ForbiddenException(
          'Only the mission owner can select an applicant',
        );
      }
      if (missions[0].status !== MissionStatus.APPROVED_PUBLISHED) {
        throw new ConflictException(
          'This mission is not open for selection (already in progress, or not yet published)',
        );
      }

      const applications: Array<{
        id: string;
        applicant_id: string;
        status: MissionApplicationStatus;
      }> = await manager.query(
        `SELECT "id", "applicant_id", "status" FROM "mission_applications"
           WHERE "id" = $1 AND "mission_id" = $2`,
        [applicationId, missionId],
      );
      if (applications.length === 0) {
        throw new NotFoundException('Application not found');
      }
      if (applications[0].status !== MissionApplicationStatus.PENDING) {
        throw new ConflictException('This application is no longer pending');
      }

      await manager.query(
        `UPDATE "mission_applications" SET "status" = 'selected', "updated_at" = now()
         WHERE "id" = $1`,
        [applicationId],
      );
      await manager.query(
        `UPDATE "mission_applications" SET "status" = 'not_selected', "updated_at" = now()
         WHERE "mission_id" = $1 AND "id" != $2 AND "status" = 'pending'`,
        [missionId, applicationId],
      );
      await manager.query(
        `UPDATE "missions"
         SET "status" = 'in_progress', "selected_application_id" = $1,
             "selected_at" = now(), "updated_at" = now()
         WHERE "id" = $2`,
        [applicationId, missionId],
      );

      return { applicantId: applications[0].applicant_id };
    });
  }

  // Returns the selected applicant's id (if any) so the controller can
  // notify them — a mission could in principle be completed with no
  // application ever selected (shouldn't happen via the normal select ->
  // in_progress path, but this stays defensive rather than assuming).
  async completeMission(
    missionId: string,
    ownerId: string,
  ): Promise<{ selectedApplicantId: string | null }> {
    const [rows]: [
      Array<{ id: string; selected_application_id: string | null }>,
      number,
    ] = await this.dataSource.query(
      `UPDATE "missions"
         SET "status" = 'completed', "completed_at" = now(), "updated_at" = now()
         WHERE "id" = $1 AND "poster_id" = $2 AND "status" = 'in_progress'
         RETURNING "id", "selected_application_id"`,
      [missionId, ownerId],
    );
    if (rows.length === 0) {
      throw new ConflictException(
        'This mission cannot be completed (not yours, or not in progress)',
      );
    }
    const selectedApplicationId = rows[0].selected_application_id;
    if (!selectedApplicationId) {
      return { selectedApplicantId: null };
    }
    const applications: Array<{ applicant_id: string }> =
      await this.dataSource.query(
        `SELECT "applicant_id" FROM "mission_applications" WHERE "id" = $1`,
        [selectedApplicationId],
      );
    return { selectedApplicantId: applications[0]?.applicant_id ?? null };
  }
}
