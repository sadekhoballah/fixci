import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddDistrictIdToUsers1785900000000 implements MigrationInterface {
  name = 'AddDistrictIdToUsers1785900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN "district_id" uuid`,
    );
    // Backfill already-registered accounts (all pre-dating this feature) to
    // a single default district rather than leaving them null — Cocody is
    // Abidjan's business hub and already seeded with both toggles open, so
    // this is a safe no-op for their actual behavior.
    await queryRunner.query(`
      UPDATE "users" SET "district_id" = (SELECT "id" FROM "districts" WHERE "name" = 'Cocody')
      WHERE "district_id" IS NULL
    `);
    await queryRunner.query(
      `ALTER TABLE "users" ALTER COLUMN "district_id" SET NOT NULL`,
    );
    await queryRunner.query(`
      ALTER TABLE "users" ADD CONSTRAINT "FK_users_district" FOREIGN KEY ("district_id") REFERENCES "districts"("id")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" DROP CONSTRAINT "FK_users_district"`,
    );
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "district_id"`);
  }
}
