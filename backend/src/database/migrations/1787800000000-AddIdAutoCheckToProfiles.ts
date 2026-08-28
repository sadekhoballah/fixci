import { MigrationInterface, QueryRunner } from 'typeorm';

// Google Vision auto-check verdict captured at ID-card / license upload time
// (uploads/id-document-check.ts), copied onto the profile when the account
// is created and surfaced in the admin review queue. jsonb, nullable — null
// for accounts registered before this shipped, or when the Redis hand-off
// lapsed / Vision was unconfigured. See StoredIdDocAnalysis.
export class AddIdAutoCheckToProfiles1787800000000
  implements MigrationInterface
{
  name = 'AddIdAutoCheckToProfiles1787800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" ADD COLUMN "id_auto_check" jsonb`,
    );
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" ADD COLUMN "license_auto_check" jsonb`,
    );
    await queryRunner.query(
      `ALTER TABLE "client_profiles" ADD COLUMN "id_auto_check" jsonb`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "client_profiles" DROP COLUMN "id_auto_check"`,
    );
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" DROP COLUMN "license_auto_check"`,
    );
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" DROP COLUMN "id_auto_check"`,
    );
  }
}
