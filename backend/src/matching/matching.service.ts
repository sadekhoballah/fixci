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

  async createServiceRequest(
    clientId: string,
    serviceCategory: ServiceCategory,
    latitude: number,
    longitude: number,
  ): Promise<CreatedServiceRequest> {
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
}
