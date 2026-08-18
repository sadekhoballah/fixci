import { MigrationInterface, QueryRunner } from 'typeorm';

// The Missions/Freelance board table. poster_id is generic (either a client
// or a craftsman — see Mission entity), not a clientId/craftsmanId split.
// selected_application_id has no FK yet: mission_applications doesn't exist
// until the next migration, and the two tables mutually reference each
// other — the FK constraint is added separately once both tables exist
// (see AddSelectedApplicationFkToMissions).
export class CreateMissions1787100000000 implements MigrationInterface {
  name = 'CreateMissions1787100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "missions" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "poster_id" uuid NOT NULL,
        "title" varchar(150) NOT NULL,
        "description" text NOT NULL,
        "category" service_category_enum,
        "location_address" text NOT NULL,
        "location" geography(Point, 4326) NOT NULL,
        "photo_storage_keys" text[],
        "status" mission_status_enum NOT NULL DEFAULT 'pending_moderation',
        "rejection_reason" text,
        "selected_application_id" uuid,
        "published_at" timestamptz,
        "selected_at" timestamptz,
        "completed_at" timestamptz,
        "archived_at" timestamptz,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_missions" PRIMARY KEY ("id"),
        CONSTRAINT "FK_missions_poster" FOREIGN KEY ("poster_id") REFERENCES "users"("id") ON DELETE RESTRICT
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "missions_location_gist" ON "missions" USING GIST ("location")`,
    );
    await queryRunner.query(
      `CREATE INDEX "missions_status_idx" ON "missions" ("status")`,
    );
    await queryRunner.query(
      `CREATE INDEX "missions_poster_id_idx" ON "missions" ("poster_id")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "missions"`);
  }
}
