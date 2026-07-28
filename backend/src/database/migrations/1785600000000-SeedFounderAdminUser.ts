import { MigrationInterface, QueryRunner } from 'typeorm';

// Seeds the founder's own SUPER_ADMIN login. The password hash below is a
// one-time temporary password generated at migration-authoring time — the
// plaintext was handed to the founder out of band (never committed here) and
// should be rotated on first login once the admin dashboard has a
// change-password screen.
export class SeedFounderAdminUser1785600000000 implements MigrationInterface {
  name = 'SeedFounderAdminUser1785600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `INSERT INTO "admin_users" ("username", "password_hash", "role") VALUES ($1, $2, 'super_admin')`,
      ['admin', '$2b$12$QoOWH8VwX26IHUbfS72qLOsRRbcegpVBBeqNGef3TR1TD/qRU8rdK'],
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DELETE FROM "admin_users" WHERE "username" = $1`, [
      'admin',
    ]);
  }
}
