import { MigrationInterface, QueryRunner } from 'typeorm';

// Second KYC document, required only for the taxi/camion categories —
// mirrors id_card_storage_key/id_verified/id_rejection_reason exactly, kept
// as its own triplet rather than a generic documents table since it's one
// extra document for two categories, not an open-ended set.
export class AddLicenseToCraftsmanProfiles1786600000000 implements MigrationInterface {
  name = 'AddLicenseToCraftsmanProfiles1786600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" ADD COLUMN "license_storage_key" varchar(255)`,
    );
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" ADD COLUMN "license_verified" boolean NOT NULL DEFAULT false`,
    );
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" ADD COLUMN "license_rejection_reason" text`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" DROP COLUMN "license_rejection_reason"`,
    );
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" DROP COLUMN "license_verified"`,
    );
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" DROP COLUMN "license_storage_key"`,
    );
  }
}
