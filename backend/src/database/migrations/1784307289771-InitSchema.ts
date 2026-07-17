import { MigrationInterface, QueryRunner } from 'typeorm';

export class InitSchema1784307289771 implements MigrationInterface {
  name = 'InitSchema1784307289771';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS postgis`);
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);

    await queryRunner.query(
      `CREATE TYPE "user_role_enum" AS ENUM ('client', 'craftsman')`,
    );
    await queryRunner.query(`
      CREATE TYPE "service_category_enum" AS ENUM (
        'plumber','electrician','ac_repair','cleaning','carpenter','mechanic',
        'painter','aluminum_work','camera_installation','tv_installation',
        'satellite_installation','construction','blacksmith'
      )
    `);
    await queryRunner.query(`
      CREATE TYPE "service_request_status_enum" AS ENUM (
        'pending','assigned','in_progress','completed','cancelled','expired'
      )
    `);

    await queryRunner.query(`
      CREATE TABLE "users" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "phone" varchar(20) NOT NULL UNIQUE,
        "full_name" varchar(120),
        "role" user_role_enum NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now()
      )
    `);

    await queryRunner.query(`
      CREATE TABLE "client_profiles" (
        "user_id" uuid PRIMARY KEY REFERENCES "users"("id") ON DELETE CASCADE,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now()
      )
    `);

    await queryRunner.query(`
      CREATE TABLE "craftsman_profiles" (
        "user_id" uuid PRIMARY KEY REFERENCES "users"("id") ON DELETE CASCADE,
        "service_category" service_category_enum NOT NULL,
        "experience_details" text,
        "id_card_storage_key" varchar(255),
        "id_verified" boolean NOT NULL DEFAULT false,
        "location" geography(Point, 4326),
        "average_rating" numeric(3,2),
        "ratings_count" integer NOT NULL DEFAULT 0,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "craftsman_profiles_location_gist" ON "craftsman_profiles" USING GIST ("location")`,
    );
    await queryRunner.query(
      `CREATE INDEX "craftsman_profiles_service_category_idx" ON "craftsman_profiles" ("service_category")`,
    );

    await queryRunner.query(`
      CREATE TABLE "service_requests" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "client_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE RESTRICT,
        "craftsman_id" uuid REFERENCES "users"("id") ON DELETE RESTRICT,
        "service_category" service_category_enum NOT NULL,
        "status" service_request_status_enum NOT NULL DEFAULT 'pending',
        "client_location" geography(Point, 4326) NOT NULL,
        "search_radius_meters" integer NOT NULL DEFAULT 5000,
        "assigned_at" timestamptz,
        "completed_at" timestamptz,
        "cancelled_at" timestamptz,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "service_requests_client_location_gist" ON "service_requests" USING GIST ("client_location")`,
    );
    await queryRunner.query(
      `CREATE INDEX "service_requests_status_idx" ON "service_requests" ("status")`,
    );
    await queryRunner.query(
      `CREATE INDEX "service_requests_craftsman_id_idx" ON "service_requests" ("craftsman_id")`,
    );

    await queryRunner.query(`
      CREATE TABLE "ratings" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "service_request_id" uuid NOT NULL UNIQUE REFERENCES "service_requests"("id") ON DELETE CASCADE,
        "client_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE RESTRICT,
        "craftsman_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE RESTRICT,
        "stars" smallint NOT NULL CHECK ("stars" BETWEEN 1 AND 5),
        "comment" text,
        "created_at" timestamptz NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "ratings_craftsman_id_idx" ON "ratings" ("craftsman_id")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "ratings"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "service_requests"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "craftsman_profiles"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "client_profiles"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "users"`);
    await queryRunner.query(
      `DROP TYPE IF EXISTS "service_request_status_enum"`,
    );
    await queryRunner.query(`DROP TYPE IF EXISTS "service_category_enum"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "user_role_enum"`);
  }
}
