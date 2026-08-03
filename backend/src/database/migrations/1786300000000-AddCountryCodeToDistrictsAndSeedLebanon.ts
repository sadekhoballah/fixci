import { MigrationInterface, QueryRunner } from 'typeorm';

// English - Arabic, matching the format already used for the app's own
// bilingual copy elsewhere — district names aren't translated per the
// client's chosen app language (see District.fromJson on the mobile side),
// so this single string needs to read clearly regardless of which of the
// app's 4 languages someone has picked.
const LEBANON_DISTRICTS = [
  'Beirut - بيروت',
  'Mount Lebanon - جبل لبنان',
  'North - الشمال',
  'Akkar - عكار',
  'Beqaa - البقاع',
  'Baalbek-Hermel - بعلبك الهرمل',
  'Nabatieh - النبطية',
  'South - الجنوب',
];

export class AddCountryCodeToDistrictsAndSeedLebanon1786300000000 implements MigrationInterface {
  name = 'AddCountryCodeToDistrictsAndSeedLebanon1786300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // DEFAULT 'CI' backfills every existing row (all of them Côte d'Ivoire
    // districts, seeded before this app supported any other market) in the
    // same statement — no separate UPDATE needed.
    await queryRunner.query(`
      ALTER TABLE "districts"
      ADD COLUMN "country_code" varchar(2) NOT NULL DEFAULT 'CI'
    `);

    // Same launch posture as CreateDistricts1785800000000's CI seed: both
    // toggles start true, since these are markets FixCi is actively
    // launching in now, not a future expansion target (see
    // DistrictsService.create's opposite default for admin-added districts).
    for (const name of LEBANON_DISTRICTS) {
      await queryRunner.query(
        `INSERT INTO "districts" ("name", "country_code") VALUES ($1, 'LB')`,
        [name],
      );
    }
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DELETE FROM "districts" WHERE "country_code" = 'LB'`,
    );
    await queryRunner.query(
      `ALTER TABLE "districts" DROP COLUMN "country_code"`,
    );
  }
}
