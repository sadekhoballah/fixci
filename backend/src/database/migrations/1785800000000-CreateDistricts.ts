import { MigrationInterface, QueryRunner } from 'typeorm';

// Both toggles default true on the seeded rows: these represent districts
// FixCi is presumed to already be operating in, so this migration alone
// must not lock out anyone already registered there. A newly admin-created
// district (POST /admin/districts) defaults both to false instead — see
// DistrictsService.create.
const SEED_DISTRICTS = [
  'Cocody',
  'Marcory',
  'Yopougon',
  'Plateau',
  'Treichville',
  'Koumassi',
  'Port-Bouët',
  'Abobo',
  'Adjamé',
  'Attécoubé',
  'Bingerville',
  'San Pédro',
  'Gagnoa',
  'Bouaké',
  'Yamoussoukro',
];

export class CreateDistricts1785800000000 implements MigrationInterface {
  name = 'CreateDistricts1785800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "districts" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "name" varchar(120) NOT NULL,
        "is_artisan_registration_active" boolean NOT NULL DEFAULT true,
        "is_client_ordering_active" boolean NOT NULL DEFAULT true,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_districts" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_districts_name" UNIQUE ("name")
      )
    `);
    for (const name of SEED_DISTRICTS) {
      await queryRunner.query(`INSERT INTO "districts" ("name") VALUES ($1)`, [
        name,
      ]);
    }
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "districts"`);
  }
}
