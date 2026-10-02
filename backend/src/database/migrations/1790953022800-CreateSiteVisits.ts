import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateSiteVisits1790953022800 implements MigrationInterface {
  name = 'CreateSiteVisits1790953022800';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "site_visits" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "ip_address" varchar(64) NOT NULL,
        "country_code" varchar(2),
        "path" varchar(255),
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_site_visits" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_site_visits_ip_address" ON "site_visits" ("ip_address")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_site_visits_created_at" ON "site_visits" ("created_at")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "site_visits"`);
  }
}
