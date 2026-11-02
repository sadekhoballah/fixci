import { MigrationInterface, QueryRunner } from 'typeorm';

// Lets a broadcast target a whole country (e.g. every craftsman in Sénégal)
// rather than one district at a time — see SendBroadcastDto.countryCode.
export class AddBroadcastTargetCountry1791400000000 implements MigrationInterface {
  name = 'AddBroadcastTargetCountry1791400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "broadcast_notifications" ADD COLUMN IF NOT EXISTS "target_country_code" varchar(2)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "broadcast_notifications" DROP COLUMN "target_country_code"`,
    );
  }
}
