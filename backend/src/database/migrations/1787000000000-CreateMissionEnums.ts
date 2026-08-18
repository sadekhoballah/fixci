import { MigrationInterface, QueryRunner } from 'typeorm';

// Two brand-new enum types for the Missions/Freelance feature — see
// database/enums/mission-status.enum.ts and mission-application-status.enum.ts
// for what each value means. Unlike service_category_enum, these have no
// ADD VALUE history yet, so a plain symmetric DROP TYPE is safe on down().
export class CreateMissionEnums1787000000000 implements MigrationInterface {
  name = 'CreateMissionEnums1787000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE "mission_status_enum" AS ENUM (
        'draft',
        'pending_moderation',
        'approved_published',
        'rejected',
        'in_progress',
        'completed',
        'archived'
      )
    `);
    await queryRunner.query(`
      CREATE TYPE "mission_application_status_enum" AS ENUM (
        'pending',
        'selected',
        'not_selected',
        'withdrawn'
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TYPE "mission_application_status_enum"`);
    await queryRunner.query(`DROP TYPE "mission_status_enum"`);
  }
}
