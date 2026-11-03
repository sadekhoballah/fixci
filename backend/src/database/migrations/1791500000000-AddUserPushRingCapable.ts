import { MigrationInterface, QueryRunner } from 'typeorm';

// True once the user's current app build can turn a data-only push into a
// ringing notification (see NotificationsService.sendToUser's ringUntil).
// Older builds can't, so they keep getting the plain notification.
export class AddUserPushRingCapable1791500000000 implements MigrationInterface {
  name = 'AddUserPushRingCapable1791500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "push_ring_capable" boolean NOT NULL DEFAULT false`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN "push_ring_capable"`,
    );
  }
}
