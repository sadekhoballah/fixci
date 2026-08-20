import { MigrationInterface, QueryRunner } from 'typeorm';

// user_reports (admin-reviewed) and user_blocks (self-service, enforced
// bidirectionally by every reader — see UserBlock's class-level comment) —
// see those entities for the full shape.
export class CreateUserSafetyTables1787700000000
  implements MigrationInterface
{
  name = 'CreateUserSafetyTables1787700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "user_reports" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "reporter_id" uuid NOT NULL,
        "reported_user_id" uuid NOT NULL,
        "reason" report_reason_enum NOT NULL,
        "message" text,
        "context_type" varchar(30),
        "context_id" uuid,
        "status" report_status_enum NOT NULL DEFAULT 'pending',
        "admin_note" text,
        "resolved_at" timestamptz,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_user_reports" PRIMARY KEY ("id"),
        CONSTRAINT "FK_user_reports_reporter" FOREIGN KEY ("reporter_id") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_user_reports_reported_user" FOREIGN KEY ("reported_user_id") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "user_reports_status_idx" ON "user_reports" ("status")`,
    );
    await queryRunner.query(
      `CREATE INDEX "user_reports_reported_user_id_idx" ON "user_reports" ("reported_user_id")`,
    );

    await queryRunner.query(`
      CREATE TABLE "user_blocks" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "blocker_id" uuid NOT NULL,
        "blocked_user_id" uuid NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_user_blocks" PRIMARY KEY ("id"),
        CONSTRAINT "FK_user_blocks_blocker" FOREIGN KEY ("blocker_id") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_user_blocks_blocked_user" FOREIGN KEY ("blocked_user_id") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    // One row per (blocker, blocked) pair — SafetyService.blockUser is a
    // plain INSERT ... ON CONFLICT DO NOTHING against this, so re-blocking
    // an already-blocked user is a harmless no-op rather than a duplicate row.
    await queryRunner.query(
      `CREATE UNIQUE INDEX "user_blocks_blocker_blocked_uniq" ON "user_blocks" ("blocker_id", "blocked_user_id")`,
    );
    // The reverse-direction lookup ("who has blocked me") every
    // getBlockedCounterpartIds call also needs — the blocker_id half of the
    // pair is already covered by the unique index above (leftmost column).
    await queryRunner.query(
      `CREATE INDEX "user_blocks_blocked_user_id_idx" ON "user_blocks" ("blocked_user_id")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "user_blocks"`);
    await queryRunner.query(`DROP TABLE "user_reports"`);
  }
}
