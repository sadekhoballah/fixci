import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateAdminUsers1785500000000 implements MigrationInterface {
  name = 'CreateAdminUsers1785500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE TYPE "admin_role_enum" AS ENUM('super_admin')`,
    );
    await queryRunner.query(`
      CREATE TABLE "admin_users" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "username" varchar(64) NOT NULL,
        "password_hash" varchar(255) NOT NULL,
        "role" "admin_role_enum" NOT NULL DEFAULT 'super_admin',
        "is_active" boolean NOT NULL DEFAULT true,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_admin_users" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_admin_users_username" UNIQUE ("username")
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "admin_users"`);
    await queryRunner.query(`DROP TYPE "admin_role_enum"`);
  }
}
