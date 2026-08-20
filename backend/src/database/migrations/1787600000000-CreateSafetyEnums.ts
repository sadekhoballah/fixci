import { MigrationInterface, QueryRunner } from 'typeorm';

// Two brand-new enum types for user reporting — see
// database/enums/report-reason.enum.ts and report-status.enum.ts for what
// each value means. No ADD VALUE history yet, so a plain symmetric
// DROP TYPE is safe on down() — mirrors CreateMissionEnums.
export class CreateSafetyEnums1787600000000 implements MigrationInterface {
  name = 'CreateSafetyEnums1787600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE "report_reason_enum" AS ENUM (
        'harassment',
        'no_show',
        'fraud',
        'inappropriate_content',
        'other'
      )
    `);
    await queryRunner.query(`
      CREATE TYPE "report_status_enum" AS ENUM (
        'pending',
        'resolved',
        'dismissed'
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TYPE "report_status_enum"`);
    await queryRunner.query(`DROP TYPE "report_reason_enum"`);
  }
}
