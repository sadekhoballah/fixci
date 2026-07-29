import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateBlacklistedPhones1786000000000
  implements MigrationInterface
{
  name = 'CreateBlacklistedPhones1786000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "blacklisted_phones" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "phone" varchar(20) NOT NULL,
        "reason" text,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_blacklisted_phones" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_blacklisted_phones_phone" UNIQUE ("phone")
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "blacklisted_phones"`);
  }
}
