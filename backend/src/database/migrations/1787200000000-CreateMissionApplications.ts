import { MigrationInterface, QueryRunner } from 'typeorm';

// "Candidater" records. The unique index is PARTIAL (WHERE status !=
// 'withdrawn') rather than a plain UNIQUE(mission_id, applicant_id) — this
// lets someone withdraw and re-apply to the same mission instead of being
// permanently locked out by their first (withdrawn) application row.
export class CreateMissionApplications1787200000000 implements MigrationInterface {
  name = 'CreateMissionApplications1787200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "mission_applications" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "mission_id" uuid NOT NULL,
        "applicant_id" uuid NOT NULL,
        "status" mission_application_status_enum NOT NULL DEFAULT 'pending',
        "applicant_location" geography(Point, 4326) NOT NULL,
        "message" text,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_mission_applications" PRIMARY KEY ("id"),
        CONSTRAINT "FK_mission_applications_mission" FOREIGN KEY ("mission_id") REFERENCES "missions"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_mission_applications_applicant" FOREIGN KEY ("applicant_id") REFERENCES "users"("id") ON DELETE RESTRICT
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "mission_applications_one_active_per_user"
      ON "mission_applications" ("mission_id", "applicant_id")
      WHERE "status" != 'withdrawn'
    `);
    await queryRunner.query(
      `CREATE INDEX "mission_applications_mission_id_idx" ON "mission_applications" ("mission_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX "mission_applications_applicant_id_idx" ON "mission_applications" ("applicant_id")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "mission_applications"`);
  }
}
