import { MigrationInterface, QueryRunner } from 'typeorm';

// Adds the "when" + "starting price" fields the mobile form is growing:
// timing_preference always has a value (defaults existing rows to
// 'unspecified'); scheduled_day_of_week/scheduled_hour are only ever set
// together, and only when timing_preference = 'scheduled' (enforced at the
// DTO layer, not by a DB constraint — same trust boundary as the rest of
// this table's optional fields). scheduled_day_of_week follows Dart's
// DateTime.weekday convention (1 = Monday .. 7 = Sunday) so the mobile side
// never has to translate between two indexing schemes.
export class AddSchedulingAndPriceToMissions1787400000000
  implements MigrationInterface
{
  name = 'AddSchedulingAndPriceToMissions1787400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE "mission_timing_preference_enum" AS ENUM (
        'unspecified',
        'immediate',
        'scheduled'
      )
    `);
    await queryRunner.query(`
      ALTER TABLE "missions"
        ADD COLUMN "timing_preference" mission_timing_preference_enum NOT NULL DEFAULT 'unspecified',
        ADD COLUMN "scheduled_day_of_week" smallint,
        ADD COLUMN "scheduled_hour" smallint,
        ADD COLUMN "starting_price" numeric(12, 2)
    `);
    await queryRunner.query(`
      ALTER TABLE "missions"
        ADD CONSTRAINT "CHK_missions_scheduled_day_of_week" CHECK ("scheduled_day_of_week" BETWEEN 1 AND 7),
        ADD CONSTRAINT "CHK_missions_scheduled_hour" CHECK ("scheduled_hour" BETWEEN 0 AND 23),
        ADD CONSTRAINT "CHK_missions_starting_price" CHECK ("starting_price" >= 0)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "missions"
        DROP COLUMN "timing_preference",
        DROP COLUMN "scheduled_day_of_week",
        DROP COLUMN "scheduled_hour",
        DROP COLUMN "starting_price"
    `);
    await queryRunner.query(`DROP TYPE "mission_timing_preference_enum"`);
  }
}
