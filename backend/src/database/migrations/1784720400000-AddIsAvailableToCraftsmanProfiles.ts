import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddIsAvailableToCraftsmanProfiles1784720400000 implements MigrationInterface {
  name = 'AddIsAvailableToCraftsmanProfiles1784720400000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" ADD COLUMN "is_available" boolean NOT NULL DEFAULT false`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" DROP COLUMN "is_available"`,
    );
  }
}
