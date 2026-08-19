import { MigrationInterface, QueryRunner } from 'typeorm';

// Backs the Missions bottom-nav badge — a plain counter rather than a
// last-seen timestamp, incremented once per mission:* notifyUser call (see
// MissionsController) and zeroed by POST /missions/mark-seen when the
// caller opens the Missions tab (see missions_home_screen.dart). Simpler
// than reconstructing "what's new since last visit" from
// mission_applications on every read, at the cost of not knowing *which*
// mission changed — acceptable since the badge only ever says "something
// changed, go look."
export class AddMissionsUnseenCountToUsers1787500000000
  implements MigrationInterface
{
  name = 'AddMissionsUnseenCountToUsers1787500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "users"
        ADD COLUMN "missions_unseen_count" integer NOT NULL DEFAULT 0
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "users" DROP COLUMN "missions_unseen_count"
    `);
  }
}
