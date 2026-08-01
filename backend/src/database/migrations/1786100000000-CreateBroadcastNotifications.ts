import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateBroadcastNotifications1786100000000 implements MigrationInterface {
  name = 'CreateBroadcastNotifications1786100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "broadcast_notifications" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "title" varchar(120) NOT NULL,
        "body" text NOT NULL,
        "target_role" "user_role_enum",
        "target_service_category" "service_category_enum",
        "target_district_id" uuid,
        "waitlist_only" boolean NOT NULL DEFAULT false,
        "recipient_count" integer NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_broadcast_notifications" PRIMARY KEY ("id"),
        CONSTRAINT "FK_broadcast_notifications_district" FOREIGN KEY ("target_district_id") REFERENCES "districts"("id")
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "broadcast_notifications"`);
  }
}
