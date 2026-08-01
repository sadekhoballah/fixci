import { MigrationInterface, QueryRunner } from 'typeorm';

// Supports self-service account deletion (UsersService.deleteAccount):
// phone must become nullable so the real number is immediately reusable for
// a fresh registration once anonymized (Postgres never treats NULL = NULL
// as a unique-constraint collision, so no placeholder-string scheme or
// partial index is needed). deleted_at is a one-way flag nothing else in
// the codebase ever clears — distinct from craftsman_profiles/
// client_profiles.is_active, which already means "admin rejected this
// account's KYC" and is recoverable via the resubmit flow.
export class AddDeletedAtAndNullablePhoneToUsers1786200000000 implements MigrationInterface {
  name = 'AddDeletedAtAndNullablePhoneToUsers1786200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN "deleted_at" timestamptz`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ALTER COLUMN "phone" DROP NOT NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ALTER COLUMN "phone" SET NOT NULL`,
    );
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "deleted_at"`);
  }
}
