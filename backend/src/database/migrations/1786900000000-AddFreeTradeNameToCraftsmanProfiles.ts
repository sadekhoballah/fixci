import { MigrationInterface, QueryRunner } from 'typeorm';

// Free-text trade name, populated only when service_category = 'other_trade'
// — see CraftsmanProfile.freeTradeName.
export class AddFreeTradeNameToCraftsmanProfiles1786900000000 implements MigrationInterface {
  name = 'AddFreeTradeNameToCraftsmanProfiles1786900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" ADD COLUMN "free_trade_name" varchar(120)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" DROP COLUMN "free_trade_name"`,
    );
  }
}
