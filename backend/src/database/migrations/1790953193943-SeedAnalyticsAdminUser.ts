import { MigrationInterface, QueryRunner } from 'typeorm';

// Seeds the "samoce" admin login, used for the new /admin/analytics stats
// page. The hash below is a one-time password generated at migration-
// authoring time; the plaintext was given by the account owner out of band
// and is never committed here. Same pattern as SeedFounderAdminUser.
export class SeedAnalyticsAdminUser1790953193943 implements MigrationInterface {
  name = 'SeedAnalyticsAdminUser1790953193943';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `INSERT INTO "admin_users" ("username", "password_hash", "role") VALUES ($1, $2, 'super_admin')`,
      ['samoce', '$2b$12$bf130Vh7yzqxFVOKX1kUreMLFq1wrslW1/AEjUAXbKNTGQ70p226a'],
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DELETE FROM "admin_users" WHERE "username" = $1`, [
      'samoce',
    ]);
  }
}
