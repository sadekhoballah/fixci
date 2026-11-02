import { Injectable, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { ServiceCategory } from '../database/enums/service-category.enum';
import type { ContactChannel } from '../database/entities/service-request-contact.entity';
import { NotificationsService } from '../firebase/notifications.service';
import { SafetyService } from '../safety/safety.service';
import { PresenceService } from './presence.service';
import {
  FALLBACK_CRAFTSMEN_COUNT,
  FALLBACK_LIST_TTL_MS,
  fallbackRadiusMetersFor,
  isTightRadiusCategory,
} from './matching.constants';

export interface FallbackCraftsman {
  id: string;
  fullName: string | null;
  phone: string;
  distanceMeters: number;
  averageRating: number | null;
  ratingsCount: number;
  completedJobsCount: number;
  isOnline: boolean;
}

export interface FallbackList {
  requestId: string;
  serviceCategory: ServiceCategory;
  // For the client app's pre-filled WhatsApp message ("... à Cocody").
  clientDistrictName: string | null;
  craftsmen: FallbackCraftsman[];
}

interface ExpiredRequest {
  id: string;
  clientId: string;
  serviceCategory: ServiceCategory;
  longitude: number;
  latitude: number;
  clientDistrictName: string | null;
}

// What the client gets when the 75s real-time window closes with nobody
// accepting (see MatchingGateway.runMatchingLoop): the nearest craftsmen of
// the requested trade, phone number included, to reach directly by
// WhatsApp or a regular call. Phone numbers are the sensitive part, so the
// list is only ever served for the caller's own request, once it has
// actually expired, for FALLBACK_LIST_TTL_MS afterwards, and only to a
// client whose own number is verified (enforced in MatchingController).
@Injectable()
export class FallbackContactsService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly presenceService: PresenceService,
    private readonly safetyService: SafetyService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async getFallbackList(
    requestId: string,
    clientId: string,
  ): Promise<FallbackList> {
    const request = await this.findExpiredRequest(requestId, clientId);
    return {
      requestId: request.id,
      serviceCategory: request.serviceCategory,
      clientDistrictName: request.clientDistrictName,
      craftsmen: await this.findCraftsmen(request),
    };
  }

  // Logs a WhatsApp / call tap and, the first time this client reaches out
  // to this craftsman for this request, pushes the craftsman a heads-up so
  // the message or call doesn't go unnoticed. Only craftsmen actually on
  // this request's list can be recorded — otherwise this route would let a
  // client push-notify any craftsman they liked.
  async recordContact(
    requestId: string,
    clientId: string,
    craftsmanId: string,
    channel: ContactChannel,
  ): Promise<void> {
    const request = await this.findExpiredRequest(requestId, clientId);
    const craftsmen = await this.findCraftsmen(request);
    if (!craftsmen.some((craftsman) => craftsman.id === craftsmanId)) {
      throw new NotFoundException('Artisan introuvable pour cette demande');
    }

    const previous: unknown[] = await this.dataSource.query(
      `SELECT 1 FROM "service_request_contacts"
       WHERE "service_request_id" = $1 AND "craftsman_id" = $2
       LIMIT 1`,
      [requestId, craftsmanId],
    );
    await this.dataSource.query(
      `INSERT INTO "service_request_contacts"
         ("service_request_id", "client_id", "craftsman_id", "channel")
       VALUES ($1, $2, $3, $4)
       ON CONFLICT ON CONSTRAINT "UQ_service_request_contacts_request_craftsman_channel"
       DO NOTHING`,
      [requestId, clientId, craftsmanId, channel],
    );
    if (previous.length > 0) return;

    void this.notificationsService.sendToUser(
      craftsmanId,
      {
        title: 'Un client vous contacte',
        body:
          channel === 'whatsapp'
            ? 'Un client Fix Pro vous écrit sur WhatsApp pour une intervention près de chez vous. Pensez à lui répondre.'
            : 'Un client Fix Pro essaie de vous appeler pour une intervention près de chez vous. Pensez à décrocher ou à le rappeler.',
      },
      { event: 'request:contacted', requestId, channel },
    );
  }

  private async findExpiredRequest(
    requestId: string,
    clientId: string,
  ): Promise<ExpiredRequest> {
    const rows: Array<{
      id: string;
      client_id: string;
      service_category: ServiceCategory;
      longitude: number;
      latitude: number;
      district_name: string | null;
    }> = await this.dataSource.query(
      `SELECT sr."id", sr."client_id", sr."service_category",
              ST_X(sr."client_location"::geometry) AS longitude,
              ST_Y(sr."client_location"::geometry) AS latitude,
              d."name" AS district_name
       FROM "service_requests" sr
       JOIN "users" u ON u."id" = sr."client_id"
       LEFT JOIN "districts" d ON d."id" = u."district_id"
       WHERE sr."id" = $1 AND sr."client_id" = $2
         AND sr."status" = 'expired'
         AND sr."updated_at" > now() - ($3 || ' milliseconds')::interval`,
      [requestId, clientId, String(FALLBACK_LIST_TTL_MS)],
    );
    if (rows.length === 0) {
      throw new NotFoundException('Demande introuvable ou trop ancienne');
    }
    const row = rows[0];
    return {
      id: row.id,
      clientId: row.client_id,
      serviceCategory: row.service_category,
      longitude: Number(row.longitude),
      latitude: Number(row.latitude),
      clientDistrictName: row.district_name,
    };
  }

  // Same eligibility gates as being matchable live — active, not deleted,
  // district open, not blocked either way — plus a verified ID: the app is
  // handing out this person's number, so only someone an admin has checked.
  // Taxi/camion additionally need the verified license, mirroring
  // PresenceService.setOnline. Online or not doesn't matter here (a
  // craftsman who never opened the app can still answer WhatsApp); it's
  // only surfaced as a badge.
  private async findCraftsmen(
    request: ExpiredRequest,
  ): Promise<FallbackCraftsman[]> {
    const blocked = await this.safetyService.getBlockedCounterpartIds(
      request.clientId,
    );
    const rows: Array<{
      user_id: string;
      full_name: string | null;
      phone: string;
      distance_meters: string;
      average_rating: string | null;
      ratings_count: number;
      completed_jobs_count: number;
    }> = await this.dataSource.query(
      `SELECT cp."user_id", u."full_name", u."phone",
              ST_Distance(cp."location", ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) AS distance_meters,
              cp."average_rating", cp."ratings_count",
              (SELECT count(*)::int FROM "service_requests" done
               WHERE done."craftsman_id" = cp."user_id" AND done."status" = 'completed') AS completed_jobs_count
       FROM "craftsman_profiles" cp
       JOIN "users" u ON u."id" = cp."user_id"
       JOIN "districts" d ON d."id" = u."district_id"
       WHERE cp."service_category" = $3
         AND cp."is_active" = true
         AND cp."id_verified" = true
         AND ($6::boolean = false OR cp."license_verified" = true)
         AND cp."location" IS NOT NULL
         AND u."deleted_at" IS NULL
         AND u."phone" IS NOT NULL
         AND d."is_artisan_registration_active" = true
         AND NOT (cp."user_id" = ANY($4::uuid[]))
         AND ST_DWithin(cp."location", ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $5)
       ORDER BY distance_meters ASC
       LIMIT $7`,
      [
        request.longitude,
        request.latitude,
        request.serviceCategory,
        [...blocked],
        fallbackRadiusMetersFor(request.serviceCategory),
        isTightRadiusCategory(request.serviceCategory),
        FALLBACK_CRAFTSMEN_COUNT,
      ],
    );
    const online = await this.presenceService.onlineAmong(
      request.serviceCategory,
      rows.map((row) => row.user_id),
    );
    return rows.map((row) => ({
      id: row.user_id,
      fullName: row.full_name,
      phone: row.phone,
      distanceMeters: Math.round(Number(row.distance_meters)),
      averageRating:
        row.average_rating === null ? null : Number(row.average_rating),
      ratingsCount: row.ratings_count,
      completedJobsCount: row.completed_jobs_count,
      isOnline: online.has(row.user_id),
    }));
  }
}
