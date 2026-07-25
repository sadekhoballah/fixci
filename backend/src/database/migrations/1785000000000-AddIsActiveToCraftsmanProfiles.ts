import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddIsActiveToCraftsmanProfiles1785000000000 implements MigrationInterface {
  name = 'AddIsActiveToCraftsmanProfiles1785000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" ADD COLUMN "is_active" boolean NOT NULL DEFAULT true`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" DROP COLUMN "is_active"`,
    );
  }
}
